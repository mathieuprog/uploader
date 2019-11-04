defmodule UploadHelpersTest do
  use ExUnit.Case, async: true

  alias Uploader.HTML.UploadHelpers
  alias Test.Support.User

  import Phoenix.HTML
  import Phoenix.HTML.Form
  import Phoenix.HTML.Tag

  test "generate upload url" do
    user = %User{name: "John", avatar_image: "john.jpg"}

    assert "john.jpg" == UploadHelpers.upload_url(user, :avatar_image)
  end

  test "generate upload url with base url option" do
    user = %User{name: "John", avatar_image: "john.jpg"}

    assert "uploads/john.jpg" ==
             UploadHelpers.upload_url(user, :avatar_image, base_url: "uploads")
  end
end
