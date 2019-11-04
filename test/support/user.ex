defmodule Test.Support.User do
  alias __MODULE__
  use Ecto.Schema
  use Uploader.Ecto.UploadableFields
  import Ecto.Changeset
  import Uploader.Ecto.Changeset

  schema "users" do
    field(:name, :string)

    uploadable_field :avatar_image,
      cast: &User.cast_avatar/2,
      filename: &User.filename_avatar/2,
      on_file_exists: :compare_hash,
      print: &User.print_avatar/2,
      uploader: Test.Support.FakeUploader
  end

  def cast_avatar(
        %Plug.Upload{filename: uploaded_filename},
        %Ecto.Changeset{} = user
      ) do
    extension = Path.extname(uploaded_filename) |> String.downcase()
    user_name = fetch_field!(user, :name) |> String.downcase()
    user_name <> extension
  end

  def filename_avatar(%User{avatar_image: avatar_image}, _field_name) do
    avatar_image
  end

  def print_avatar(%User{avatar_image: avatar_image}, _field_name) do
    avatar_image
  end

  @required_fields ~w(name)a
  @optional_fields ~w(avatar_image)a

  def changeset(user, attrs) do
    user
    |> cast_with_upload(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end
end
