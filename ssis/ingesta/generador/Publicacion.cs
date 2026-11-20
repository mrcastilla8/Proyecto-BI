using System;
using System.IO;
using System.Linq;

internal sealed class Publicacion
{
    private readonly Source source;
    private readonly string version;
    private readonly string templates;

    public Publicacion(Source source, string version, string templates)
    {
        this.source = source;
        this.version = version;
        this.templates = templates;
    }

    public string Temporales()
    {
        return "SET NOCOUNT ON; IF DB_NAME()<>'BI_OLIST' THROW 51900,'SQL_DATABASE',1;\n" +
            "CREATE TABLE #Lote(batch_id bigint NOT NULL, expected int NOT NULL, session_id int NOT NULL);\n" +
            "CREATE TABLE #FilasIngesta(source_row_number bigint NOT NULL PRIMARY KEY," +
            string.Join(",", source.Fields.Select(x => x.Bracket + " " + x.RawType + " NULL")) + ");";
    }

    public string Lote() { return Render("lote.sql"); }
    public string Fallo() { return Render("fallo.sql"); }

    public string Publicar(bool inject)
    {
        var fields = source.Fields;
        var select = fields.Select((c, i) => Conversion(c, "f." + c.Bracket) + " AS c" + i);
        var errors = fields.Select((c, i) => "(" + (i + 1) + ",'" + c.Name + "'," + Error(c, i) + ")");
        var classify =
            "SELECT f.source_row_number, parsed.*, fault.field_name, fault.reason_code INTO #Clasificadas\n" +
            "FROM #FilasIngesta AS f CROSS APPLY (SELECT " + string.Join(",", select) + ") AS parsed\n" +
            "OUTER APPLY (SELECT TOP (1) field_name,reason_code FROM (VALUES\n" + string.Join(",\n", errors) +
            "\n) AS defectos(pos,field_name,reason_code) WHERE reason_code IS NOT NULL ORDER BY pos) AS fault;";
        return Render("publicar.sql")
            .Replace("{{CLASIFICAR}}", classify)
            .Replace("{{CAMPOS}}", string.Join(",", fields.Select(c => c.Bracket)))
            .Replace("{{CONVERTIDOS}}", string.Join(",", fields.Select((_, i) => "c" + i)))
            .Replace("{{FALLO_INYECTADO}}", inject ?
                "IF @accepted>0 THROW 51999,'Fallo inyectado después de escribir en staging',1;" : "");
    }

    private string Render(string file)
    {
        return File.ReadAllText(Path.Combine(templates, file))
            .Replace("{{TABLA}}", "stg.[" + source.Name + "]")
            .Replace("{{FUENTE}}", source.Name)
            .Replace("{{ARCHIVO}}", source.file)
            .Replace("{{VERSION}}", version);
    }

    private static string Conversion(Column c, string value)
    {
        return "TRY_CONVERT(" + c.SqlType + ",NULLIF(" + value + ",N'')" +
            (c.Kind == "DATETIME2" ? ",120" : "") + ")";
    }

    private static string Error(Column c, int index)
    {
        var v = "f." + c.Bracket;
        var cast = "parsed.c" + index;
        string empty = v + " IS NULL OR DATALENGTH(" + v + ")=0";
        string rules;
        if (c.IsText)
        {
            rules = " WHEN DATALENGTH(" + v + ")>" + (2 * c.Size) + " THEN 'TEXT_LENGTH'";
            if (c.Kind != "NVARCHAR")
                rules += " WHEN CONVERT(varbinary(max)," + v + ")<>CONVERT(varbinary(max)," +
                    "CONVERT(nvarchar(max),CONVERT(varchar(max)," + v + "))) THEN 'TEXT_CODEPAGE'";
            if (c.Name.EndsWith("_zip_code_prefix", StringComparison.Ordinal))
                rules += " WHEN DATALENGTH(" + v + ")<>10 OR " + v + " COLLATE Latin1_General_100_BIN2 LIKE N'%[^0-9]%' THEN 'ZIP_FORMAT'";
        }
        else if (c.Kind == "DATETIME2")
        {
            rules = " WHEN " + cast + " IS NULL OR DATALENGTH(" + v + ")<>38 OR CONVERT(varbinary(max)," +
                v + ")<>CONVERT(varbinary(max),CONVERT(nvarchar(19)," + cast + ",120)) THEN 'DATETIME_FORMAT'";
        }
        else
        {
            string unsigned = "(CASE WHEN LEFT(" + v + ",1) IN (N'-',N'+') THEN SUBSTRING(" + v + ",2,96) ELSE " + v + " END)";
            string characters = c.Kind == "DECIMAL" ? "[^0-9.]" : "[^0-9]";
            rules = " WHEN " + cast + " IS NULL OR " + unsigned + " COLLATE Latin1_General_100_BIN2 LIKE N'%" + characters +
                "%' OR " + unsigned + " COLLATE Latin1_General_100_BIN2 NOT LIKE N'%[0-9]%' OR DATALENGTH(" + v +
                ")<>DATALENGTH(TRIM(" + v + ")) THEN 'NUMBER_FORMAT'";
            if (c.Kind == "DECIMAL")
                rules += " WHEN CHARINDEX(N'.'," + v + ")>0 AND LEN(" + v + ")-CHARINDEX(N'.'," + v + ")>" +
                    c.Scale + " THEN 'DECIMAL_SCALE'";
            if (c.Name == "review_score")
                rules += " WHEN " + cast + " NOT BETWEEN 1 AND 5 THEN 'REVIEW_SCORE_RANGE'";
        }
        return "CASE WHEN " + empty + (c.Nullable ? " THEN NULL" : " THEN 'REQUIRED' WHEN NULLIF(TRIM(" + v +
            "),N'') IS NULL THEN 'REQUIRED'") + rules + " END";
    }
}
