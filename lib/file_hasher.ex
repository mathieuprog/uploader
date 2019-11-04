defmodule Uploader.FileHasher do
  defp sha256(chunks_enum) do
    chunks_enum
    |> Enum.reduce(
      :crypto.hash_init(:sha256),
      &:crypto.hash_update(&2, &1)
    )
    |> :crypto.hash_final()
    |> Base.encode16()
    |> String.downcase()
  end

  @doc ~S"""
  Compute and return the hash of a file.
  """
  def hash_file_content(file_path) do
    sha256(File.stream!(file_path, [], 2_048))
  end
end
