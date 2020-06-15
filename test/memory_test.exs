defmodule CsvParser.Tests.Memory do
	use CsvParser.Tests.Base

	test "reads from an in-memory representation" do
		expected = [
			{:ok, ["Id", "First Name", "Age", "Date"]},
			{:ok, ["1562", "Dulce", "32", "15/10/2017"]},
			{:ok, ["1582", "Mara", "25", "16/08/2016"]},
			{:ok, ["2587", "Philip", "37", "21/05/2015"]},
			{:ok, ["3549", "Kathleen", "25", "15/10/2017"]},
		]

		data = [
			["Id", "First Name", "Age", "Date"],
			["1562", "Dulce", "32", "15/10/2017"],
			["1582", "Mara", "25", "16/08/2016"],
			["2587", "Philip", "37", "21/05/2015"],
			["3549", "Kathleen", "25", "15/10/2017"]
		]

		actual = data
		|> CsvParser.memory()
		|> CsvParser.reduce!([], fn row, acc -> [row | acc]end)
		|> Enum.reverse()

		assert actual == expected
	end
end
