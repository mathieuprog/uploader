defmodule Uploader do
  @callback maybe_copy_file(
              tmp_file_path :: String.t(),
              new_file_path :: String.t(),
              on_file_exists :: atom | nil
            ) :: :ok | {:error, term}

  @doc ~S"""
  Store all the uploaded files.

  This function is expected to be called inside a transaction:

      Multi.new()
      |> Multi.insert(:user, user_changeset)
      |> Multi.run(:upload_files, fn _repo, %{user: user} ->
        Uploader.store_files(user)
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{user: user}} ->
          {:ok, user}

        {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
          {:error, changeset}

        {:error, :upload_files, {:file_path_exists, file_path}, _changes} ->
          raise "file upload failed: path \"#{file_path}\" already exists"
      end

  This function fetches all the uploadable schema fields (with all of their options)
  from the given Schema struct (see `Uploader.Ecto.UploadableFields`), and for each
  field calls the `maybe_copy_file/4` callback function. This callback function is
  called from the module defined in the `:uploader` option of the field (by default,
  the module `Uploader.LocalUploader` is used). Below is an example on how to define
  a custom module implementing the `maybe_copy_file/4` callback function in the Schema:

      schema "users" do
        uploadable_field :avatar_image, uploader: AmazonS3Uploader
        # other fields
      end

  In case of success `{:ok, nil}` is returned, otherwise `{:error, error_tuple}`
  is returned with `error_tuple` being a two-elements tuple describing the error.
  This tuple is in fact the returned error value of the call to the
  `maybe_copy_file/4` function. An example of a returned error value is
  `{:error, {:file_path_exists, file_path}}`.
  """
  @spec store_files(struct) :: {:ok, nil} | {:error, term}
  def store_files(%{__struct__: _struct_name} = entity) do
    uploadable_fields_with_opts = entity.__struct__.get_uploadable_fields()

    try do
      for {uploadable_field, opts} <- uploadable_fields_with_opts,
          field_contains_new_uploaded_file?(entity, uploadable_field) do
        uploader = Keyword.get(opts, :uploader, Uploader.LocalUploader)
        on_file_exists = Keyword.get(opts, :on_file_exists)
        directory = Keyword.get(opts, :directory, "")

        filenames =
          Keyword.get(opts, :filename, &filename/2).(entity, uploadable_field)
          |> List.wrap()

        %Plug.Upload{path: tmp_file_path} =
          Map.fetch!(entity, String.to_atom("uploaded_" <> Atom.to_string(uploadable_field)))

        for filename <- filenames do
          new_file_path = Path.join(directory, filename)

          status_copy_file =
            apply(uploader, :maybe_copy_file, [
              tmp_file_path,
              new_file_path,
              on_file_exists
            ])

          case status_copy_file do
            :ok -> :ok
            {:error, _} = error -> throw({:break, error})
          end
        end
      end

      {:ok, nil}
    catch
      {:break, error} -> error
    end
  end

  defp field_contains_new_uploaded_file?(entity, uploadable_field) do
    Map.fetch!(entity, uploadable_field) &&
      Map.fetch!(entity, String.to_atom("uploaded_" <> Atom.to_string(uploadable_field)))
  end

  defp filename(%{__struct__: _struct_name} = entity, field_name) do
    Map.fetch!(entity, field_name)
  end
end
