defmodule Explorer.UserDataDump do
  @moduledoc """
  Run the process of creating and restoring dumps of user inserted data
  """

  alias Ecto.Adapters.SQL
  alias ExAws.S3
  alias ExAws.S3.Upload
  alias Explorer.Repo

  @user_table_names Enum.map([Explorer.Chain.Address.Name, Explorer.Chain.SmartContract], fn module ->
                      module.__schema__(:source)
                    end)
  @network Application.get_env(:explorer, __MODULE__)[:network]
  @bucket Application.get_env(:explorer, __MODULE__)[:dump_bucket]

  @doc """
  Generate a dump of the data on user tables and upload to an object storage
  compatible with the AWS S3 API
  """
  # sobelow_skip ["SQL.Query", "Traversal"]
  def generate_dump(table_names \\ @user_table_names) do
    table_names
    |> Enum.reduce([], fn table_name, results ->
      {_, response} = SQL.query(Repo, postgres_copy(table_name, "TO STDOUT"))

      file_written =
        case File.write("/tmp/#{table_name}.csv", response.rows) do
          :ok -> {:ok, :done}
          result -> result
        end

      [file_written, upload_dump(table_name) | results]
    end)
    |> treat_received_results
  after
    table_names |> Enum.each(fn name -> File.rm("/tmp/#{name}.csv") end)
  end

  @doc """
  Retrieve a dump of the data on user tables from an object storage compatible
  with the AWS S3 API and restore it to the current schema
  """
  # sobelow_skip ["SQL.Stream", "Traversal"]
  def restore_from_dump(table_names \\ @user_table_names) do
    table_names
    |> Enum.reduce([], fn table_name, results ->
      stream = SQL.stream(Repo, postgres_copy(table_name, "FROM STDIN"))

      [
        download_dump(table_name),
        Repo.transaction(fn -> Enum.into([File.read!("/tmp/#{table_name}.csv")], stream) end) | results
      ]
    end)
    |> treat_received_results
  after
    table_names |> Enum.each(fn name -> File.rm("/tmp/#{name}.csv") end)
  end

  defp download_dump(table_name) do
    @bucket
    |> S3.download_file("#{@network}/#{table_name}.csv", "/tmp/#{table_name}.csv")
    |> ExAws.request()
  rescue
    e in ExAws.Error -> {:error, e.message}
  end

  defp upload_dump(table_name) do
    "/tmp/#{table_name}.csv"
    |> Upload.stream_file()
    |> S3.upload(@bucket, "#{@network}/#{table_name}.csv")
    |> ExAws.request()
  end

  defp postgres_copy(table_name, to_from) do
    "COPY #{table_name} #{to_from} DELIMITER ',' CSV HEADER;"
  end

  defp treat_received_results(list_of_results) do
    list_of_results
    |> Enum.filter(fn {result, _} -> result == :error end)
    |> Enum.reduce([], fn {_, result}, acc -> [result | acc] end)
    |> case do
      [] -> {:ok, :done}
      errors -> {:error, errors}
    end
  end
end
