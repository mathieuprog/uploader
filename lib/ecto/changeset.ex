defmodule Uploader.Ecto.Changeset do
  import Ecto.Changeset

  @doc ~S"""
  Returns a changeset for the given `struct` (see `Ecto.Changeset.cast/4`).

  Casts file uploads (`Plug.Upload` structs) into a generated UUID filename or, if the
  `:cast` option is present, into a value obtained by a call to the user-defined
  cast function.

  In order not to lose the `Plug.Upload` structs after casting, these structs are
  stored into virtual fields named by the original fields that held the file uploads
  prefixed by "uploaded_".

  Example:
    * A param named "image" contains a file upload (`Plug.Upload` struct);
    * `cast_with_upload/3` casts the `Plug.Upload` struct into a filename;
    * the changeset field :image contains the filename;
    * the changeset field :uploaded_image contains the `Plug.Upload` struct.
  """
  def cast_with_upload(%{__struct__: _} = struct, params, permitted) do
    uploadable_fields_with_opts = struct.__struct__.get_uploadable_fields()
    uploadable_fields = Keyword.keys(uploadable_fields_with_opts)

    # Move the file uploads—Plug.Upload structs—into the virtual fields
    # as we do not want to lose these structs after casting. Uploading the
    # files takes place later on and we need the data from the Plug.Upload
    # structs.
    params_with_virtual_fields =
      Enum.map(params, fn
        {k, %Plug.Upload{} = v} -> {"uploaded_" <> k, v}
        {k, v} -> {k, v}
      end)
      |> Enum.into(%{})

    # List of virtual fields containing the file uploads.
    uploadable_virtual_fields =
      uploadable_fields |> Enum.map(&String.to_atom("uploaded_" <> Atom.to_string(&1)))

    # Create a changeset with the Plug.Upload structs. The reason an intermediary
    # changeset is created here (we still did not cast the Plug.Upload structs
    # into filenames) is because we want to pass this changeset to the user-defined
    # cast function. The changeset is passed because the filename might be deduced
    # from a field from the Schema.
    permitted = (permitted -- uploadable_fields) ++ uploadable_virtual_fields
    changeset = cast(struct, params_with_virtual_fields, permitted)

    # Cast the Plug.Upload structs.
    casted_upload_params =
      Enum.filter(params, fn
        {_, %Plug.Upload{}} -> true
        _ -> false
      end)
      |> Enum.map(fn {k, %Plug.Upload{} = upload} ->
        uploadable_field_opts = Keyword.fetch!(uploadable_fields_with_opts, String.to_atom(k))

        fn_cast_upload = Keyword.get(uploadable_field_opts, :cast, &cast_upload/2)

        {k, fn_cast_upload.(upload, changeset)}
      end)
      |> Enum.into(%{})

    # Create a changeset containing the casted Plug.Upload structs (a Plug.Upload struct
    # will typically be casted into a filename.
    changeset_filenames = cast(struct, casted_upload_params, uploadable_fields)

    Ecto.Changeset.merge(changeset, changeset_filenames)
  end

  defp cast_upload(
         %Plug.Upload{filename: uploaded_filename},
         %Ecto.Changeset{}
       ) do
    filename = Ecto.UUID.generate()
    extension = Path.extname(uploaded_filename) |> String.downcase()
    filename <> extension
  end
end
