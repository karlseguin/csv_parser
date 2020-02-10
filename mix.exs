defmodule CsvParser.MixProject do
	use Mix.Project

	def project do
		[
			app: :csv_parser,
			deps: deps(),
			version: "0.0.1",
			elixir: "~> 1.10.0",
			elixirc_paths: paths(Mix.env),
			build_embedded: Mix.env == :prod,
			start_permanent: Mix.env() == :prod,
		 	description: "A simple csv parser that supports both CSV and XLSX",
			package: [
				licenses: ["MIT"],
				links: %{
					"git" => "https://github.com/karlseguin/csv_parser"
				},
				maintainers: ["Karl Seguin"],
			],
		]
	end

	defp paths(:test), do: paths(:prod) ++ ["test/support"]
	defp paths(_), do: ["lib"]

	defp deps do
		[
			{:csv, "~> 2.3.0"},
			{:erlsom, "~> 1.5.0"},
			{:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
		]
	end
end
