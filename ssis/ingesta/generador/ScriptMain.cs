using System;
using System.Data.OleDb;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using Microsoft.SqlServer.Dts.Runtime;
using Microsoft.SqlServer.Dts.Tasks.ScriptTask;

namespace ST_OrdersSnapshot
{
    [SSISScriptTaskEntryPoint]
    public partial class ScriptMain : VSTARTScriptObjectModelBase
    {
        private static readonly UTF8Encoding Utf8 = new UTF8Encoding(false, true);

        public void Main()
        {
            string task = (string)Dts.Variables["System::TaskName"].Value;
            string snapshot = null;
            try
            {
                if (task == "Comprobar entradas")
                {
                    var root = Root();
                    foreach (var file in Text("User::SourceFiles").Split('|'))
                        if (!File.Exists(Path.Combine(root, file)))
                            throw new InvalidDataException("CSV_MISSING: " + file);
                    using (var connection = new OleDbConnection(Sql().ConnectionString))
                    {
                        connection.Open();
                        using (var query = new OleDbCommand(
                            "SELECT CASE WHEN DB_NAME() <> 'BI_OLIST' OR OBJECT_ID(N'audit.Batch',N'U') IS NULL THEN 0 ELSE 1 END",
                            connection))
                            if (Convert.ToInt32(query.ExecuteScalar()) != 1)
                                throw new InvalidDataException("SQL_SCHEMA: destino de ingesta no disponible.");
                    }
                }
                else if (task == "Preparar CSV")
                {
                    var root = Root();
                    Dts.Connections["CM_SQL"].ConnectionString = Sql().ConnectionString;
                    snapshot = Path.Combine(Path.GetTempPath(), "olist-" + Guid.NewGuid().ToString("N") + ".csv");
                    Dts.Variables["User::Snapshot"].Value = snapshot;
                    string hash;
                    int rows = WriteSnapshot(Path.Combine(root, Text("User::SourceFile")), snapshot,
                        Text("User::Header"), Text("User::FieldCaps").Split(',').Select(int.Parse).ToArray(), out hash);
                    Dts.Connections["CM_CSV"].ConnectionString = snapshot;
                    Dts.Variables["User::RowsExpected"].Value = rows;
                    Dts.Variables["User::SourceHash"].Value = hash;
                }
                else
                {
                    Delete(Text("User::Snapshot"));
                }
                Dts.TaskResult = (int)DTSExecResult.Success;
            }
            catch (Exception ex)
            {
                Delete(snapshot);
                string details = ex is InvalidDataException ? ex.Message : ex.GetType().Name;
                Dts.Events.FireError(1, "Ingesta Olist", details, "", 0);
                Dts.TaskResult = (int)DTSExecResult.Failure;
            }
        }

        private string Text(string name) { return (string)Dts.Variables[name].Value; }

        private string Root()
        {
            var root = Text("$Project::CSV_ROOT");
            if (string.IsNullOrWhiteSpace(root) || !Directory.Exists(root))
                throw new InvalidDataException("CSV_ROOT: indica una carpeta existente.");
            return root;
        }

        private OleDbConnectionStringBuilder Sql()
        {
            var server = Text("$Project::SQL_SERVER");
            var database = Text("$Project::SQL_DATABASE");
            if (string.IsNullOrWhiteSpace(server) || !string.Equals(database, "BI_OLIST", StringComparison.OrdinalIgnoreCase))
                throw new InvalidDataException("SQL_SERVER y SQL_DATABASE=BI_OLIST son obligatorios.");
            var connection = new OleDbConnectionStringBuilder();
            connection.Provider = "MSOLEDBSQL19";
            connection["Integrated Security"] = "SSPI";
            connection["Use Encryption for Data"] = "Optional";
            connection["Data Source"] = server;
            connection["Initial Catalog"] = database;
            return connection;
        }

        private static void Delete(string path)
        {
            if (string.IsNullOrEmpty(path)) return;
            try { File.Delete(path); }
            catch (IOException) { }
            catch (UnauthorizedAccessException) { }
        }

        public static int WriteSnapshot(string source, string snapshot, string header, int[] caps, out string hash)
        {
            using (var file = new FileStream(source, FileMode.Open, FileAccess.Read, FileShare.Read, 65536))
            using (var sha = SHA256.Create())
            {
                hash = BitConverter.ToString(sha.ComputeHash(file)).Replace("-", "").ToLowerInvariant();
                file.Position = 0;
                using (var reader = new StreamReader(file, Utf8, false, 65536))
                using (var writer = new StreamWriter(new FileStream(snapshot, FileMode.CreateNew, FileAccess.Write,
                    FileShare.None, 65536), Utf8, 65536))
                {
                    if (reader.Peek() == '\ufeff') reader.Read();
                    var firstLine = reader.ReadLine();
                    if (firstLine == null || !firstLine.Split(',').Select(UnquoteHeader).SequenceEqual(header.Split(',')))
                        throw new InvalidDataException("CSV_HEADER: encabezado distinto del contrato.");
                    writer.Write("source_row_number," + header + "\n");
                    return AddOrdinals(reader, writer, caps);
                }
            }
        }

        private static string UnquoteHeader(string name)
        {
            return name.Length >= 2 && name[0] == '"' && name[name.Length - 1] == '"'
                ? name.Substring(1, name.Length - 2) : name;
        }

        private static int AddOrdinals(TextReader reader, TextWriter writer, int[] caps)
        {
            var field = new StringBuilder();
            int ordinal = 0;
            while (reader.Peek() >= 0)
            {
                ordinal = checked(ordinal + 1);
                writer.Write(ordinal.ToString(CultureInfo.InvariantCulture));
                for (int index = 0; index < caps.Length; index++)
                {
                    field.Clear();
                    bool quoted = reader.Peek() == '"';
                    bool closed = false;
                    int limit = caps[index];
                    bool overflow = false;
                    if (quoted) reader.Read();
                    while (true)
                    {
                        int next = reader.Peek();
                        if (next < 0 || (!quoted && (next == ',' || next == '\r' || next == '\n'))) break;
                        char value = (char)reader.Read();
                        if (value == '"')
                        {
                            if (!quoted) throw Framing(ordinal);
                            if (reader.Peek() != '"')
                            {
                                closed = true;
                                break;
                            }
                            reader.Read();
                        }
                        if (field.Length < limit) field.Append(value);
                        else overflow = true;
                    }
                    if (quoted && !closed) throw Framing(ordinal);
                    if (overflow)
                    {
                        // A marker of the same length is always over the text limit and never a valid scalar.
                        field.Clear();
                        field.Append('~', limit);
                    }
                    writer.Write(",\"");
                    for (int offset = 0; offset < field.Length; offset++)
                    {
                        var value = field[offset];
                        if (value == '"') writer.Write('"');
                        writer.Write(value);
                    }
                    writer.Write('"');
                    int separator = reader.Read();
                    if (index < caps.Length - 1)
                    {
                        if (separator != ',') throw Framing(ordinal);
                    }
                    else
                    {
                        if (separator == '\r' && reader.Peek() == '\n') reader.Read();
                        if (separator != -1 && separator != '\r' && separator != '\n') throw Framing(ordinal);
                        writer.Write('\n');
                    }
                }
            }
            return ordinal;
        }

        private static InvalidDataException Framing(int ordinal)
        {
            return new InvalidDataException("CSV_FRAMING: registro " + ordinal.ToString(CultureInfo.InvariantCulture));
        }
    }
}
