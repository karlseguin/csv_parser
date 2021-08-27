defmodule CsvParser.Tests.Xlsx do
	use CsvParser.Tests.Base

	@common "test/data/common.xlsx"

	test "error on unknown file" do
		assert CsvParser.read("invalid", type: :xlsx) == {:error, :enoent}
	end

	test "error on unknown sheet" do
		assert CsvParser.read(@common, sheet_index: 9000) == {:error, :unknown_sheet}
	end

	test "error on unknown sheet!" do
		assert_raise RuntimeError, "unknown_sheet", fn -> CsvParser.read!(@common, sheet_index: 4928) end
	end

	test "reads a file with default options" do
		expected = [
			{:ok, ["Id", "First Name", "Age", "Date"]},
			{:ok, ["1562", "Dulce", "32", "15/10/2017"]},
			{:ok, ["1582", "Mara", "25", "16/08/2016"]},
			{:ok, ["2587", "Philip", "37", "21/05/2015"]},
			{:ok, ["3549", "Kathleen", "25", "15/10/2017"]},
		]

		assert CsvParser.read!(@common, sheet_index: 1) == expected
		assert CsvParser.read(@common, sheet_index: 1) == {:ok, expected}
		assert CsvParser.read!(@common, sheet_index: 1, type: :xlsx) == expected
	end

	test "reads a file with rows as maps" do
		assert CsvParser.read!(@common, sheet_index: 1, map: true) == [
			{:ok, %{"Id" => "1562", "First Name" => "Dulce", "Age" => "32", "Date" => "15/10/2017"}},
			{:ok, %{"Id" => "1582", "First Name" => "Mara", "Age" => "25", "Date" => "16/08/2016"}},
			{:ok, %{"Id" => "2587", "First Name" => "Philip", "Age" => "37", "Date" => "21/05/2015"}},
			{:ok, %{"Id" => "3549", "First Name" => "Kathleen", "Age" => "25", "Date" => "15/10/2017"}},
		]

		assert CsvParser.read!(@common, sheet_index: 4, map: :lower) == [
			{:ok, %{"id" => "1562", "first name" => "Dulce", "age" => "32"}},
		]

		assert CsvParser.read!(@common, sheet_index: 4, map: :upper) == [
			{:ok, %{"ID" => "1562", "FIRST NAME" => "Dulce", "AGE" => "32"}},
		]

		fun = fn keys -> Enum.map(keys, fn key -> "#{key}!" end) end
		assert CsvParser.read!(@common, sheet_index: 4, map: fun) == [
			{:ok, %{"Id!" => "1562", "First Name!" => "Dulce", "Age!" => "32"}},
		]
	end

	test "reads the specified sheet" do
		assert CsvParser.read!(@common, sheet_index: 2) == [{:ok, ["test"]}]
	end

	test "different column count" do
		assert CsvParser.read!(@common, sheet_index: 3) == [
			{:ok, ["a", "b"]},
			{:ok, ["c", nil]},
			{:ok, ["1", "2", "3"]}
		]
	end

	test "handles gaps" do
		assert CsvParser.read!(@common, sheet_index: 5) == [
			{:ok, ["Id", "First Name", "Age", "Date"]},
			{:ok, ["1562", "Dulce", nil, nil]},
			{:ok, ["1582", "Mara", "25", "16/08/2016"]},
			{:ok, ["2587", nil, "37", "21/05/2015"]},
			{:ok, [nil, nil, nil, "15/10/2017"]},
		]
		assert CsvParser.read!(@common, sheet_index: 5, map: :lower) == [
			{:ok, %{"id" => "1562", "first name" => "Dulce", "age" => nil, "date" => nil}},
			{:ok, %{"age" => "25", "date" => "16/08/2016", "first name" => "Mara", "id" => "1582"}},
			{:ok, %{"age" => "37", "date" => "21/05/2015", "first name" => nil, "id" => "2587"}},
			{:ok, %{"age" => nil, "date" => "15/10/2017", "first name" => nil, "id" => nil}}
		]
	end
end
