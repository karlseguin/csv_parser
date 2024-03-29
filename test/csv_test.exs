defmodule CsvParser.Tests.Csv do
	use CsvParser.Tests.Base

	@one "test/data/one.csv"
	@gaps "test/data/gaps.csv"
	@common "test/data/common.csv"
	@jagged_rows "test/data/jagged_rows.csv"

	test "reads a file with default options" do
		expected = [
			{:ok, ["Id", "First Name", "Age", "Date"]},
			{:ok, ["1562", "Dulce", "32", "15/10/2017"]},
			{:ok, ["1582", "Mara", "25", "16/08/2016"]},
			{:ok, ["2587", "Philip", "37", "21/05/2015"]},
			{:ok, ["3549", "Kathleen", "25", "15/10/2017"]},
		]

		assert CsvParser.read!(@common) == expected
		assert CsvParser.read(@common) == {:ok, expected}
		assert CsvParser.read!(@common, type: :csv) == expected
	end

	test "reads a file with rows as maps" do
		assert CsvParser.read!(@common, map: true) == [
			{:ok, %{"Id" => "1562", "First Name" => "Dulce", "Age" => "32", "Date" => "15/10/2017"}},
			{:ok, %{"Id" => "1582", "First Name" => "Mara", "Age" => "25", "Date" => "16/08/2016"}},
			{:ok, %{"Id" => "2587", "First Name" => "Philip", "Age" => "37", "Date" => "21/05/2015"}},
			{:ok, %{"Id" => "3549", "First Name" => "Kathleen", "Age" => "25", "Date" => "15/10/2017"}},
		]

		assert CsvParser.read!(@one, map: :lower) == [
			{:ok, %{"id" => "1562", "first name" => "Dulce", "age" => "32"}},
		]

		assert CsvParser.read!(@one, map: :upper) == [
			{:ok, %{"ID" => "1562", "FIRST NAME" => "Dulce", "AGE" => "32"}},
		]

		fun = fn keys -> Enum.map(keys, fn key -> "#{key}!" end) end
		assert CsvParser.read!(@one, map: fun) == [
			{:ok, %{"Id!" => "1562", "First Name!" => "Dulce", "Age!" => "32"}},
		]
	end

	test "reduce with header lookup" do
		fun = fn keys -> Enum.map(keys, fn key -> "#{key}!" end) end
		csv = CsvParser.new!(@one, map: fun, header_lookup: true)

		{lookup, res} = CsvParser.reduce!(csv, [], fn row, acc -> [row | acc] end)

		assert lookup == %{
			"Id!" => "Id",
			"First Name!" => "First Name",
			"Age!" => "Age",
		}

		assert res == [
			{:ok, %{"Id!" => "1562", "First Name!" => "Dulce", "Age!" => "32"}}
		]
	end

	test "error on unknown file" do
		assert CsvParser.read("404", type: :csv) == {:error, :enoent}
		assert_raise RuntimeError, "enoent", fn -> CsvParser.read!("404", type: :csv) end
	end

	test "different column count" do
		assert CsvParser.read!(@jagged_rows) == [
			{:ok, ["a", "b"]},
			{:ok, ["c"]},
			{:ok, ["1", "2", "3"]}
		]

		assert CsvParser.read!(@jagged_rows, validate_row_length: true) == [
			{:ok, ["a", "b"]},
			{:error, "Row has length 1 - expected length 2 on line 2"},
			{:error, "Row has length 3 - expected length 2 on line 3"}
		]
	end

	test "reduce" do
		result = CsvParser.reduce!(@one, [], fn {:ok, row}, acc -> [row | acc] end, map: :lower)
		assert result == [%{"age" => "32", "first name" => "Dulce", "id" => "1562"}]
	end

	test "handles gaps" do
		assert CsvParser.read!(@gaps, sheet_index: 5) == [
			{:ok, ["Id", "First Name", "Age", "Date"]},
			{:ok, ["1562", "Dulce", nil, nil]},
			{:ok, ["1582", "Mara", "25", "16/08/2016"]},
			{:ok, ["2587", nil, "37", "21/05/2015"]},
			{:ok, [nil, nil, nil, "15/10/2017"]},
		]
		assert CsvParser.read!(@gaps, sheet_index: 5, map: :lower) == [
			{:ok, %{"id" => "1562", "first name" => "Dulce", "age" => nil, "date" => nil}},
			{:ok, %{"age" => "25", "date" => "16/08/2016", "first name" => "Mara", "id" => "1582"}},
			{:ok, %{"age" => "37", "date" => "21/05/2015", "first name" => nil, "id" => "2587"}},
			{:ok, %{"age" => nil, "date" => "15/10/2017", "first name" => nil, "id" => nil}}
		]
	end

	test "csv with lines" do
		assert ["1,2,3", "4,5,6"]
		|> CsvParser.lines!()
		|> CsvParser.reduce!([], fn line, acc -> [elem(line, 1) | acc] end)
		|> Enum.reverse() == [["1", "2", "3"], ["4", "5", "6"]]
	end

end
