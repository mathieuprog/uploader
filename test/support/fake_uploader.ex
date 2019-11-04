defmodule Test.Support.FakeUploader do
  @behaviour Uploader

  def maybe_copy_file(_tmp_file_path, _new_file_path, _on_file_exists \\ nil) do
    :ok
  end
end
