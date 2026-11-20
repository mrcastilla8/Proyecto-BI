using System;
using System.IO;
using System.Linq;
using Microsoft.SqlServer.Dts.Pipeline.Wrapper;
using Microsoft.SqlServer.Dts.Runtime;
using DataType = Microsoft.SqlServer.Dts.Runtime.Wrapper.DataType;

internal static class RevisarConversion
{
    private static void Main(string[] args)
    {
        if (args.Length < 1 || args.Length > 2)
            throw new ArgumentException("Indica el paquete de entrada y, opcionalmente, una nueva salida de ensayo.");
        var app = new Application { TargetServerVersion = DTSTargetServerVersion.SQLServer2025 };
        var package = app.LoadPackage(args[0], null);
        if (package.Name != "ETL_OrderReviews")
            throw new InvalidDataException("Se requiere ETL_OrderReviews.");
        Inspect(package);
        if (args.Length == 1)
            return;
        if (File.Exists(args[1]))
            throw new IOException("La salida debe ser un archivo de ensayo nuevo.");
        ConvertComponent(package).Description = "Sonda de mantenimiento de metadatos";
        app.SaveToXml(args[1], package, null);
        var saved = app.LoadPackage(args[1], null);
        if (ConvertComponent(saved).Description != "Sonda de mantenimiento de metadatos")
            throw new InvalidDataException("No persistió la edición de metadatos.");
        Console.WriteLine("Metadatos después de guardar y recargar:");
        Inspect(saved);
    }

    private static MainPipe Pipe(Package package)
    {
        return (MainPipe)package.Executables.Cast<TaskHost>()
            .Single(task => task.Name == "Leer OrderReviews y cargar temporal").InnerObject;
    }

    private static IDTSComponentMetaData100 ConvertComponent(Package package)
    {
        return Pipe(package).ComponentMetaDataCollection.Cast<IDTSComponentMetaData100>()
            .Single(component => component.Name == "Decodificar UTF-8");
    }

    private static void Inspect(Package package)
    {
        var pipe = Pipe(package);
        var conversion = ConvertComponent(package);
        var input = conversion.InputCollection[0];
        var path = pipe.PathCollection.Cast<IDTSPath100>().Single(item => item.EndPoint.ID == input.ID);
        var source = path.StartPoint.OutputColumnCollection.Cast<IDTSOutputColumn100>()
            .ToDictionary(column => column.LineageID);
        var used = input.InputColumnCollection.Cast<IDTSInputColumn100>().ToDictionary(column => column.LineageID);
        var output = conversion.OutputCollection.Cast<IDTSOutput100>().Single(item => !item.IsErrorOut);
        var destination = pipe.ComponentMetaDataCollection.Cast<IDTSComponentMetaData100>()
            .Single(component => component.Name == "OLE DB Destination #FilasIngesta").InputCollection[0];
        var mapped = destination.InputColumnCollection.Cast<IDTSInputColumn100>().ToDictionary(column => column.LineageID);
        if (output.SynchronousInputID != input.ID || output.OutputColumnCollection.Count != 7)
            throw new InvalidDataException("Salida de conversión inesperada.");
        foreach (IDTSOutputColumn100 column in output.OutputColumnCollection)
        {
            int lineage = Convert.ToInt32(column.CustomPropertyCollection["SourceInputColumnLineageID"].Value);
            var original = source[lineage];
            var binding = mapped[column.LineageID];
            var external = destination.ExternalMetadataColumnCollection.GetObjectByID(binding.ExternalMetadataColumnID);
            bool lob = original.Name == "review_comment_message";
            if (used[lineage].Name != original.Name || column.Name != "U_" + original.Name ||
                original.CodePage != 65001 || original.DataType != (lob ? DataType.DT_TEXT : DataType.DT_STR) ||
                column.DataType != (lob ? DataType.DT_NTEXT : DataType.DT_WSTR) ||
                external.Name != original.Name || external.DataType != column.DataType || external.Length != column.Length)
                throw new InvalidDataException("Tipo o linaje incoherente: " + original.Name);
            Console.WriteLine("{0}: {1}/{2} (CP {3}) -> {4}/{5} -> {6}; linaje {7} -> {8}",
                original.Name, original.DataType, original.Length, original.CodePage, column.DataType,
                column.Length, external.Name, lineage, column.LineageID);
        }
    }
}
