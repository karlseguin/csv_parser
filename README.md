# A Basic CSV Parser

This is a basic CSV parser that will parse either 2007 xlsx or plain CSV files.

This is not based on [xlsxir](https://hex.pm/packages/xlsxir]), which is much more powerful, but also more complicated. xlsxir stores data in ets table which makes it great to randomly access the data, but is more heavy handed if you just want a one-time forward pass.

However, the CSV parsing is delegated to [csv](https://hex.pm/packages/csv)

The entire CSV will be loaded in memory.

# .csv and .xlsx

To keep everything identical between the two formats, xlsx type information is discarded and all data is returned as a binary.

If you use CSV-specific options, such as `validate_row_length: true`, then the csv and xlsx may behave differently. This is fine if you're only dealing with one format or the other. If, on the other hand, you want consistent behaviour across both formats, you should avoid passing such parameters and deal with this logic in your on reduce handler.

Alternatively, you could submit a PR to make the xlsx parser support the option you want.

# Issues and Feature Requests

CsvParser was built to deal with very basic data. It has not been extensively tested. I'm happy to fix bugs [and add features], but please provide a basic sample .xlsx file that 

# Usage

If you just want to bulk-read everything into a list of lists, you can use:

```
CsvParser.read(path_to_file)
```

or the `read!` alternative.

If you want more control, user `new/2` + `reduce!/3`:

```
with {:ok, csv} <- Csv.new(path_to_file) do
  CsvParser.reduce(csv, [], fn row, acc ->
    [row | acc]
  end)
end
```

Note that each `row` will be a tuple of either `{:ok, [...]}` or `{:error, an error}`

Currently, with default options, you'll only ever get `{:ok, [...]}`, but its exposed this way for future compatibility.

# Header / Maps
You can pass `map: true` to get rows as maps rather than lists. The first row will be used as the keys.

# Empty Cells / Rows

Empty rows are removed

Empty cells are nil

If you're using map rows (by passing the `:map` option) and the first row is messy, the output will probably be bad.
