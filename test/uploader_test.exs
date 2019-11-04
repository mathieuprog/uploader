defmodule UploaderTest do
  use ExUnit.Case, async: true

  doctest Uploader

  alias Test.Support.User

  test "store files" do
    upload = %Plug.Upload{path: "/tmp/tmp1.jpg", filename: "1.jpg"}

    user_changeset =
      User.changeset(%User{}, %{
        "name" => "John",
        "avatar_image" => upload
      })

    user = Ecto.Changeset.apply_changes(user_changeset)

    assert user.avatar_image == "john.jpg"
    assert user.uploaded_avatar_image == upload
    assert Uploader.store_files(user) == {:ok, nil}
  end
end
