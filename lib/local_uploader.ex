defmodule Uploader.LocalUploader do
  @moduledoc ~S"""
  Store file uploads locally. This module implements the `maybe_copy_file/4` callback
  function defined in the `Uploader` module.
  """

  import Uploader.FileHasher, only: [hash_file_content: 1]

  @behaviour Uploader

  @doc ~S"""
  Copies the uploaded file to a given new file path.

  The third optional argument `on_file_exists` allows to specify what should
  happen in case the filename already exists. If no value is given and the filename
  already exists, the file is not copied and an error is returned. This behaviour
  may be changed by setting the value to:

    * `:overwrite`: overwrite the file if the file path already exists.
    * `:compare_hash`: do not copy the file if the file path already exists;
    if the hashes of the files' content are not equal, return an error.

  This function returns `:ok` in case of success. If an error occurs, a two-elements
  tuple is returned with the first element being `:error` and the second element another
  two-elements tuple describing the type of error and a value. For example:
  `{:error, {:file_path_exists, file_path}}`.
  """
  def maybe_copy_file(tmp_file_path, new_file_path, on_file_exists \\ nil) do
    maybe_copy_file(tmp_file_path, new_file_path, on_file_exists,
      file_exists: File.exists?(new_file_path)
    )
  end

  defp maybe_copy_file(tmp_file_path, new_file_path, _, file_exists: false) do
    copy_file(tmp_file_path, new_file_path)
  end

  defp maybe_copy_file(tmp_file_path, new_file_path, :overwrite, file_exists: true) do
    copy_file(tmp_file_path, new_file_path)
  end

  defp maybe_copy_file(tmp_file_path, new_file_path, :compare_hash, file_exists: true) do
    have_same_hash = hash_file_content(tmp_file_path) == hash_file_content(new_file_path)

    if have_same_hash do
      :ok
    else
      {:error, {:file_path_exists, new_file_path}}
    end
  end

  defp maybe_copy_file(_tmp_file_path, new_file_path, _, file_exists: true) do
    {:error, {:file_path_exists, new_file_path}}
  end

  defp copy_file(tmp_file_path, new_file_path) do
    File.mkdir_p!(Path.dirname(new_file_path))
    File.cp!(tmp_file_path, new_file_path)

    :ok
  end
end
