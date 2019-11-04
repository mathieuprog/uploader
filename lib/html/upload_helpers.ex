defmodule Uploader.HTML.UploadHelpers do
  @moduledoc ~S"""
  Provides a view helper to render the URL to uploaded files.
  """

  @doc ~S"""
  Renders the URL to an uploaded file.

  You may specify the `:base_url` option to prepend the base URL.
  """
  def upload_url(entity, field_name, opts \\ []) do
    base_url = Keyword.get(opts, :base_url, "")

    uploadable_fields_with_opts = entity.__struct__.get_uploadable_fields()
    opts = Keyword.fetch!(uploadable_fields_with_opts, field_name)

    url = Keyword.get(opts, :print, &print/2).(entity, field_name)

    Path.join(base_url, url)
  end

  defp print(%{__struct__: _struct_name} = entity, field_name) do
    Map.fetch!(entity, field_name)
  end
end
