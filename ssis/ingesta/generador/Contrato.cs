using System;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using System.Web.Script.Serialization;

internal sealed class ContractDocument
{
    public string version { get; set; }
    public string source_contract_status { get; set; }
    public string[] source_files { get; set; }
    public Source[] staging_sources { get; set; }

    public static ContractDocument Load(string path)
    {
        var contract = new JavaScriptSerializer().Deserialize<ContractDocument>(File.ReadAllText(path));
        if (contract.version != "1.0.0" || contract.source_contract_status != "APROBADO" ||
            contract.staging_sources.Length != 9 ||
            !contract.source_files.SequenceEqual(contract.staging_sources.Select(x => x.file)))
            throw new InvalidDataException("Contrato de ingesta no aprobado o lista de fuentes distinta.");
        foreach (var source in contract.staging_sources)
            source.Validate();
        return contract;
    }
}

internal sealed class Source
{
    public string file { get; set; }
    public string fixture { get; set; }
    public string table { get; set; }
    public string status { get; set; }
    public string[] columns { get; set; }
    public Column[] Fields { get; private set; }
    public string Name { get { return table.Substring(4); } }
    public string Package { get { return "ETL_" + (Name == "ProductCategoryTranslation" ? "CategoryTranslation" : Name); } }
    public string Header { get { return string.Join(",", Fields.Select(x => x.Name)); } }
    public string Caps { get { return string.Join(",", Fields.Select(x => x.Cap.ToString(CultureInfo.InvariantCulture))); } }

    public void Validate()
    {
        if (status != "APROBADO" || !Regex.IsMatch(table, @"^stg\.[A-Za-z]+$") ||
            !Regex.IsMatch(file, @"^[a-z_]+\.csv$") || !Regex.IsMatch(fixture, @"^[a-z_]+\.csv$"))
            throw new InvalidDataException("Origen inválido en el contrato.");
        Fields = columns.Select(Column.Parse).ToArray();
        if (!Fields.Any() || Fields.Select(c => c.Name).Distinct().Count() != Fields.Length)
            throw new InvalidDataException("Columnas vacías o duplicadas.");
    }
}

internal sealed class Column
{
    public string Name;
    public string SqlType;
    public string Kind;
    public int Size;
    public int Scale;
    public bool Nullable;
    public bool IsText { get { return Kind == "VARCHAR" || Kind == "NVARCHAR" || Kind == "CHAR"; } }
    public int Cap { get { return IsText ? Size + 1 : 96; } }
    public bool IsLob { get { return Cap > 4000; } }
    public string RawType { get { return IsLob ? "nvarchar(max)" : "nvarchar(" + Cap + ")"; } }
    public string Bracket { get { return "[" + Name + "]"; } }

    public static Column Parse(string definition)
    {
        var m = Regex.Match(definition,
            @"^(?<name>[a-z_]+) (?<type>(?<kind>VARCHAR|NVARCHAR|CHAR|INT|TINYINT|DATETIME2|DECIMAL)(?:\((?<size>\d+)(?:,(?<scale>\d+))?\))?)(?<nullable> NULL)?$");
        if (!m.Success) throw new InvalidDataException("Columna no soportada: " + definition);
        return new Column {
            Name = m.Groups["name"].Value, SqlType = m.Groups["type"].Value,
            Kind = m.Groups["kind"].Value, Size = Number(m.Groups["size"]), Scale = Number(m.Groups["scale"]),
            Nullable = m.Groups["nullable"].Success
        };
    }

    private static int Number(Group group)
    {
        return group.Success ? int.Parse(group.Value, CultureInfo.InvariantCulture) : 0;
    }
}
