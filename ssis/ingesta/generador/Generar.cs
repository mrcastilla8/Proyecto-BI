using System;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Xml.Linq;
using Microsoft.SqlServer.Dts.Pipeline.Wrapper;
using Microsoft.SqlServer.Dts.Runtime;
using Microsoft.SqlServer.Dts.Tasks.ExecuteSQLTask;
using Microsoft.SqlServer.Dts.Tasks.ScriptTask;
using Microsoft.SqlServer.VSTAHosting;
using R = Microsoft.SqlServer.Dts.Runtime.Wrapper;
using App = Microsoft.SqlServer.Dts.Runtime.Application;

internal sealed class Generador
{
    private const string ProjectName = "ETL_Olist_Ingesta";
    private const string ScriptName = "ST_OrdersSnapshot";
    private const string SqlDefaults = "Provider=MSOLEDBSQL19;Integrated Security=SSPI;Use Encryption for Data=Optional;";
    private static readonly string[] Params = { "CSV_ROOT", "SQL_SERVER", "SQL_DATABASE" };
    private readonly App app = new App { TargetServerVersion = DTSTargetServerVersion.SQLServer2025 };
    private readonly string root;
    private readonly string output;
    private readonly string vsta;
    private readonly byte[] scriptBinary;

    private Generador(string root, string output, string assembly)
    {
        this.root = root;
        this.output = output;
        vsta = Path.Combine(root, "vsta");
        scriptBinary = File.ReadAllBytes(assembly);
    }

    private static int Main(string[] args)
    {
        if (args.Length < 5 || args.Length > 7)
            throw new ArgumentException("Contrato, generador, plantilla .dtproj, salida, ensamblado y opciones.");
        var contract = ContractDocument.Load(args[0]);
        bool update = args.Skip(5).Contains("--actualizar");
        string inject = args.Skip(5).SingleOrDefault(option => option != "--actualizar");
        if (inject != null && !contract.staging_sources.Any(s => s.Name == inject))
            throw new ArgumentException("Fuente de fallo desconocida.");
        var engine = new Generador(args[1], args[3], args[4]);
        if (update)
            engine.UpdatePublication(contract, args[2], inject);
        else
            engine.Build(contract, args[2], inject);
        return 0;
    }

    private void UpdatePublication(ContractDocument contract, string template, string inject)
    {
        var directory = Path.GetDirectoryName(template);
        var master = app.LoadPackage(Path.Combine(directory, "ETL_Master.dtsx"), null);
        UpdateScript(Task(master, "Comprobar entradas"));
        SaveUpdated(master);
        foreach (var source in contract.staging_sources)
        {
            var package = app.LoadPackage(Path.Combine(directory, source.Package + ".dtsx"), null);
            var publication = new Publicacion(source, contract.version, Path.Combine(root, "sql"));
            ((ExecuteSQLTask)Task(package, "Crear temporales de sesión").InnerObject).SqlStatementSource = publication.Temporales();
            ((ExecuteSQLTask)Task(package, "Publicar y conciliar").InnerObject).SqlStatementSource = publication.Publicar(inject == source.Name);
            UpdateScript(Task(package, "Preparar CSV"));
            SaveUpdated(package);
        }
        File.Copy(template, Path.Combine(output, Path.GetFileName(template)));
        File.Copy(Path.Combine(directory, "Project.params"), Path.Combine(output, "Project.params"));
        Console.WriteLine("Actualizadas las tareas de publicación y la configuración del catálogo; paquetes reabiertos.");
    }

    private static TaskHost Task(Package package, string name)
    {
        return package.Executables.OfType<TaskHost>().Single(host => host.Name == name);
    }

    private void UpdateScript(TaskHost host)
    {
        var storage = ((ScriptTask)host.InnerObject).ScriptStorage;
        storage.AssemblyCode = scriptBinary;
        SaveScriptItem(storage, "ScriptMain.cs", Path.Combine(root, "ScriptMain.cs"));
    }

    private void SaveUpdated(Package package)
    {
        var path = Path.Combine(output, package.Name + ".dtsx");
        app.SaveToXml(path, package, null);
        app.LoadPackage(path, null).Dispose();
    }

    private void Build(ContractDocument contract, string template, string inject)
    {
        Directory.CreateDirectory(output);
        var bundle = Path.Combine(output, ProjectName + ".ispac");
        using (var memory = new MemoryStream())
        using (var project = Project.CreateProject(memory))
        {
            project.Name = ProjectName;
            project.CreatorName = "Equipo BI Olist";
            project.CreatorComputerName = "LOCAL";
            project.ProtectionLevel = DTSProtectionLevel.DontSaveSensitive;
            project.TargetServerVersion = DTSTargetServerVersion.SQLServer2025;
            foreach (var parameter in Params)
                project.Parameters.Add(parameter, TypeCode.String).Value = parameter == "SQL_DATABASE" ? "BI_OLIST" : "";

            var master = Package("ETL_Master");
            project.PackageItems.Add(master, master.Name + ".dtsx");
            master.Variables.Add("SourceFiles", true, "User", string.Join("|", contract.source_files));
            var previous = Script(master, "Comprobar entradas", ParameterList() + ",User::SourceFiles", "");
            foreach (var source in contract.staging_sources)
            {
                var package = Package(source.Package);
                package.MaximumErrorCount = 0; // Leave failure branches active for audit and cleanup.
                project.PackageItems.Add(package, package.Name + ".dtsx");
                BuildSource(package, source, contract.version, inject == source.Name);

                var call = (TaskHost)master.Executables.Add("STOCK:ExecutePackageTask");
                call.Name = "Ingerir " + source.Name;
                call.Properties["UseProjectReference"].SetValue(call, true);
                call.Properties["PackageName"].SetValue(call, package.Name + ".dtsx");
                call.DelayValidation = true;
                call.FailPackageOnFailure = true;
                master.PrecedenceConstraints.Add(previous, call);
                previous = call;
            }
            project.SaveTo(bundle);
            foreach (var item in project.PackageItems)
                app.SaveToXml(Path.Combine(output, item.StreamName), item.Package, null);
        }
        using (var test = Project.OpenProject(bundle))
            if (test.PackageItems.Count != 10 || test.Parameters.Count != 3)
                throw new InvalidDataException("Proyecto SSIS incompleto.");

        var designer = XDocument.Load(template);
        using (var archive = ZipFile.OpenRead(bundle))
        {
            using (var reader = archive.GetEntry("@Project.manifest").Open())
                designer.Descendants("Manifest").Single().ReplaceNodes(XDocument.Load(reader).Root);
            archive.GetEntry("Project.params").ExtractToFile(Path.Combine(output, "Project.params"), true);
        }
        designer.Save(Path.Combine(output, ProjectName + ".dtproj"));
        Console.WriteLine("Generados y reabiertos: maestro y nueve fuentes, SQL Server 2025.");
    }

    private static Package Package(string name)
    {
        return new Package {
            Name = name, CreatorName = "Equipo BI Olist", CreatorComputerName = "LOCAL",
            ProtectionLevel = DTSProtectionLevel.DontSaveSensitive, DelayValidation = true
        };
    }

    private TaskHost Script(Package package, string name, string read, string write)
    {
        var host = (TaskHost)package.Executables.Add("STOCK:ScriptTask");
        host.Name = name;
        host.FailPackageOnFailure = name == "Comprobar entradas" || name == "Preparar CSV";
        var task = (ScriptTask)host.InnerObject;
        task.ScriptLanguage = "Microsoft Visual C# 2022";
        task.ScriptProjectName = ScriptName;
        task.ReadOnlyVariables = "System::TaskName" + (read == "" ? "" : "," + read);
        task.ReadWriteVariables = write;
        var storage = task.ScriptStorage;
        storage.AssemblyName = ScriptName + ".dll";
        storage.AssemblyCode = scriptBinary;
        foreach (var path in Directory.GetFiles(vsta, "*", SearchOption.AllDirectories))
        {
            string item = path.Substring(vsta.Length + 1);
            SaveScriptItem(storage, item, path);
        }
        SaveScriptItem(storage, "ScriptMain.cs", Path.Combine(root, "ScriptMain.cs"));
        return host;
    }

    private static void SaveScriptItem(VSTAScriptProjectStorage storage, string item, string path)
    {
        var encoding = item == "Project" ? VSTAScriptProjectStorage.Encoding.UTF16LE : VSTAScriptProjectStorage.Encoding.UTF8;
        storage.ScriptFiles[item] = new VSTAScriptProjectStorage.VSTAScriptFile(encoding, File.ReadAllText(path));
    }

    private void BuildSource(Package package, Source source, string version, bool inject)
    {
        package.Variables.Add("SourceFile", true, "User", source.file);
        package.Variables.Add("Header", true, "User", source.Header);
        package.Variables.Add("FieldCaps", true, "User", source.Caps);
        package.Variables.Add("Snapshot", false, "User", "");
        package.Variables.Add("SourceHash", false, "User", "");
        package.Variables.Add("RowsExpected", false, "User", 0);
        package.Variables.Add("RowsRead", false, "User", 0);
        package.Variables.Add("Omitir", false, "User", 0);

        var sql = package.Connections.Add("OLEDB");
        sql.Name = "CM_SQL";
        sql.ConnectionString = SqlDefaults;
        sql.DelayValidation = true;
        sql.Properties["RetainSameConnection"].SetValue(sql, true);
        var flat = package.Connections.Add("FLATFILE");
        flat.Name = "CM_CSV";
        flat.DelayValidation = true;
        var designInput = Path.Combine(output, "diseno.csv");
        File.WriteAllText(designInput, "source_row_number," + source.Header + "\n");
        flat.ConnectionString = designInput;
        FlatMetadata(flat, source);

        var commands = new Publicacion(source, version, Path.Combine(root, "sql"));
        var prepare = Script(package, "Preparar CSV", ParameterList() + ",User::SourceFile,User::Header,User::FieldCaps",
            "User::Snapshot,User::RowsExpected,User::SourceHash");
        var create = Sql(package, sql, "Crear temporales de sesión", commands.Temporales());
        var resolve = Sql(package, sql, "Identificar y bloquear lote", commands.Lote());
        Bind(resolve, 0, "SourceHash", 129, 64);
        Bind(resolve, 1, "RowsExpected", 3, -1);
        var resolver = (ExecuteSQLTask)resolve.InnerObject;
        resolver.ResultSetType = ResultSetType.ResultSetType_SingleRow;
        var result = resolver.ResultSetBindings.Add();
        result.ResultName = "0";
        result.DtsVariableName = "User::Omitir";
        var flow = BuildFlow(package, source, flat, sql);
        flat.ConnectionString = source.file;
        File.Delete(designInput);

        var publish = Sql(package, sql, "Publicar y conciliar", commands.Publicar(inject));
        Bind(publish, 0, "RowsRead", 3, -1);
        var fail = Sql(package, sql, "Registrar fallo del flujo", commands.Fallo());
        var skip = Sql(package, sql, "OMITIDO_COMPLETE", "PRINT 'OMITIDO_COMPLETE';");
        var cleanup = Script(package, "Limpiar temporal local", "User::Snapshot", "");
        var failedCleanup = Script(package, "Limpiar tras fallo", "User::Snapshot", "");
        var skippedCleanup = Script(package, "Limpiar archivo omitido", "User::Snapshot", "");
        Edge(package, prepare, create);
        Edge(package, create, resolve);
        Edge(package, resolve, flow, DTSExecResult.Success, "@[User::Omitir] == 0");
        Edge(package, resolve, skip, DTSExecResult.Success, "@[User::Omitir] == 1");
        Edge(package, flow, cleanup);
        Edge(package, cleanup, publish, DTSExecResult.Completion);
        Edge(package, flow, failedCleanup, DTSExecResult.Failure);
        Edge(package, failedCleanup, fail, DTSExecResult.Completion);
        Edge(package, skip, skippedCleanup, DTSExecResult.Completion);
        foreach (var task in new[] {create, resolve})
            Edge(package, task, Script(package, "Limpiar tras " + task.Name, "User::Snapshot", ""), DTSExecResult.Failure);
        foreach (var required in new[] {create, resolve, publish, fail, skip})
            required.FailPackageOnFailure = true;
    }

    private static string ParameterList()
    {
        return string.Join(",", Params.Select(name => "$Project::" + name));
    }

    private static void FlatMetadata(ConnectionManager flat, Source source)
    {
        var file = (R.IDTSConnectionManagerFlatFile100)flat.InnerObject;
        file.Format = "Delimited";
        file.CodePage = 65001;
        file.TextQualifier = "\"";
        file.ColumnNamesInFirstDataRow = true;
        file.HeaderRowDelimiter = "\n";
        file.RowDelimiter = "\n";
        FlatColumn(file, "source_row_number", ",", 20, R.DataType.DT_I8, false);
        foreach (var field in source.Fields)
            FlatColumn(file, field.Name, field == source.Fields.Last() ? "\n" : ",",
                field.IsLob ? 0 : field.Cap * 3, field.IsLob ? R.DataType.DT_TEXT : R.DataType.DT_STR, true);
    }

    private static void FlatColumn(R.IDTSConnectionManagerFlatFile100 file, string name, string delimiter,
        int length, R.DataType type, bool quoted)
    {
        var column = file.Columns.Add();
        column.ColumnType = "Delimited";
        column.ColumnDelimiter = delimiter;
        column.MaximumWidth = length;
        column.TextQualified = quoted;
        column.DataType = type;
        ((R.IDTSName100)column).Name = name;
    }

    private static TaskHost BuildFlow(Package package, Source source, ConnectionManager flat, ConnectionManager sql)
    {
        var flow = (TaskHost)package.Executables.Add("STOCK:PipelineTask");
        flow.Name = "Leer " + source.Name + " y cargar temporal";
        flow.DelayValidation = true;
        var pipe = (MainPipe)flow.InnerObject;
        pipe.DefaultBufferMaxRows = source.Name == "Geolocation" ? 2048 : 256;
        pipe.DefaultBufferSize = 1024 * 1024;

        CManagedComponentWrapper design;
        var file = Component(pipe, "Flat File Source " + source.Name, "DTSAdapter.FlatFileSource.9", out design);
        Connect(file, flat);
        design.AcquireConnections(null);
        try { design.ReinitializeMetaData(); }
        finally { design.ReleaseConnections(); }

        var convert = Component(pipe, "Decodificar UTF-8", "DTSTransform.DataConvert.9", out design);
        var input = convert.InputCollection[0];
        Link(pipe, Output(file), input);
        var available = input.GetVirtualInput();
        var converted = Output(convert);
        foreach (var field in source.Fields)
        {
            var column = available.VirtualInputColumnCollection.Cast<IDTSVirtualInputColumn100>()
                .Single(x => x.Name == field.Name);
            var used = design.SetUsageType(input.ID, available, column.LineageID, DTSUsageType.UT_READONLY);
            var unicode = design.InsertOutputColumnAt(converted.ID, converted.OutputColumnCollection.Count,
                "U_" + field.Name, "Unicode");
            design.SetOutputColumnDataTypeProperties(converted.ID, unicode.ID,
                field.IsLob ? R.DataType.DT_NTEXT : R.DataType.DT_WSTR, field.IsLob ? 0 : field.Cap, 0, 0, 0);
            design.SetOutputColumnProperty(converted.ID, unicode.ID, "SourceInputColumnLineageID", used.LineageID);
        }

        var count = Component(pipe, "Contar filas", "DTSTransform.RowCount.9", out design);
        design.SetComponentProperty("VariableName", "User::RowsRead");
        Link(pipe, converted, count.InputCollection[0]);
        var dest = Component(pipe, "OLE DB Destination #FilasIngesta", "DTSAdapter.OLEDBDestination.9", out design);
        Connect(dest, sql);
        dest.ValidateExternalMetadata = false;
        design.SetComponentProperty("AccessMode", 3);
        design.SetComponentProperty("OpenRowset", "#FilasIngesta");
        design.SetComponentProperty("FastLoadKeepNulls", true);
        design.SetComponentProperty("FastLoadMaxInsertCommitSize", 512);
        design.SetComponentProperty("FastLoadOptions", "ROWS_PER_BATCH=512");
        var destInput = dest.InputCollection[0];
        Link(pipe, Output(count), destInput);
        var raw = destInput.GetVirtualInput();
        Map(design, destInput, raw, "source_row_number", "source_row_number", R.DataType.DT_I8, 0);
        foreach (var field in source.Fields)
            Map(design, destInput, raw, "U_" + field.Name, field.Name,
                field.IsLob ? R.DataType.DT_NTEXT : R.DataType.DT_WSTR, field.IsLob ? 0 : field.Cap);
        return flow;
    }

    private static void Map(CManagedComponentWrapper design, IDTSInput100 input, IDTSVirtualInput100 raw,
        string column, string target, R.DataType type, int length)
    {
        var source = raw.VirtualInputColumnCollection.Cast<IDTSVirtualInputColumn100>().Single(x => x.Name == column);
        var used = design.SetUsageType(input.ID, raw, source.LineageID, DTSUsageType.UT_READONLY);
        var external = input.ExternalMetadataColumnCollection.New();
        external.Name = target;
        external.DataType = type;
        if (length > 0) external.Length = length;
        design.MapInputColumn(input.ID, used.ID, external.ID);
    }

    private static IDTSOutput100 Output(IDTSComponentMetaData100 component)
    {
        return component.OutputCollection.Cast<IDTSOutput100>().First(item => !item.IsErrorOut);
    }

    private static void Link(MainPipe pipe, IDTSOutput100 from, IDTSInput100 to)
    {
        pipe.PathCollection.New().AttachPathAndPropagateNotifications(from, to);
    }

    private static void Connect(IDTSComponentMetaData100 component, ConnectionManager connection)
    {
        var runtime = component.RuntimeConnectionCollection[0];
        runtime.ConnectionManager = DtsConvert.GetExtendedInterface(connection);
        runtime.ConnectionManagerID = connection.ID;
    }

    private static IDTSComponentMetaData100 Component(MainPipe pipe, string name, string classId,
        out CManagedComponentWrapper design)
    {
        var component = pipe.ComponentMetaDataCollection.New();
        component.ComponentClassID = classId;
        design = component.Instantiate();
        design.ProvideComponentProperties();
        component.Name = name;
        return component;
    }

    private static TaskHost Sql(Package package, ConnectionManager connection, string name, string statement)
    {
        var host = (TaskHost)package.Executables.Add("STOCK:SQLTask");
        host.Name = name;
        host.DelayValidation = true;
        var task = (ExecuteSQLTask)host.InnerObject;
        task.Connection = connection.Name;
        task.SqlStatementSource = statement;
        task.BypassPrepare = true;
        task.TimeOut = 0;
        return host;
    }

    private static void Bind(TaskHost host, int index, string variable, int type, int size)
    {
        var binding = ((ExecuteSQLTask)host.InnerObject).ParameterBindings.Add();
        binding.ParameterName = index.ToString();
        binding.DtsVariableName = "User::" + variable;
        binding.ParameterDirection = ParameterDirections.Input;
        binding.DataType = type;
        binding.ParameterSize = size;
    }

    private static void Edge(Package package, Executable from, Executable to,
        DTSExecResult value = DTSExecResult.Success, string expression = null)
    {
        var edge = package.PrecedenceConstraints.Add(from, to);
        edge.Value = value;
        if (expression == null) return;
        edge.EvalOp = DTSPrecedenceEvalOp.ExpressionAndConstraint;
        edge.Expression = expression;
    }
}
