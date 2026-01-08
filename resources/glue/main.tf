resource "aws_glue_catalog_database" "this" {
  name = var.database_name
}

resource "aws_glue_catalog_table" "this" {
  count = length(var.tables)

  database_name = aws_glue_catalog_database.this.name
  name          = var.tables[count.index].name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    "classification" = "json"
    "compressionType" = "none"
  }

  storage_descriptor {
    location      = var.tables[count.index].location
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "json-ser-de"
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
      parameters = {
        "serialization.format" = "1"
      }
    }

    dynamic "columns" {
        for_each = var.tables[count.index].columns
        content {
            name = columns.value.name
            type = columns.value.type
        }
    }
  }
}
