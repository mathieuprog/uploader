# Uploader

`Uploader` helps you with storing file uploads.

There are numerous file upload libraries for Elixir already available, however
this library was made in order to have a finer control over how `Plug.Upload`
are casted into schema fields, over the filenames that should be generated,
the strategy to apply for existing file paths, etc.

Imagine a single image upload that must to be stored multiple times with filenames
in different languages for SEO purposes. The writing of this library was motivated
to address such advanced use cases.

## Define the Schema fields holding uploads

```elixir
defmodule MyApp.User do
  use Ecto.Schema
  use Uploader.Ecto.UploadableFields

  schema "posts" do
    uploadable_field :avatar_image
  end
end
```

You may import `:uploader`'s formatter configuration by importing
`uploader` into your `.formatter.exs` file (this allows for example to keep
`uploadable_field :avatar_image` without parentheses when running `mix format`).

```elixir
[
  import_deps: [:ecto, :phoenix, :uploader],
  #...
]
```

## Cast `Plug.Upload` structs

In order to cast file uploads (`Plug.Upload` structs) into filenames, you must
call `cast_with_upload/3` from the `Uploader.Ecto.Changeset` module for the
given Schema struct and params. Note that, in addition to casting file uploads,
`cast_with_upload/3` implicitly calls `Ecto.Changeset.cast/4` for the given params
and returns the changeset.

```elixir
import Uploader.Ecto.Changeset

schema "user" do
  uploadable_field :avatar_image
end

@required_fields ~w(avatar_image)a
@optional_fields ~w()a

def changeset(user, attrs) do
  user
  |> cast_with_upload(attrs, @required_fields ++ @optional_fields)
  |> validate_required(@required_fields)
end
```

## Copy the uploaded files

This library expects the storing of files to happen in a transaction. This is done
with a call to `Uploader.store_files/1` given a Schema struct.

```elixir
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
```

## Print URLs to uploaded files

A view helper is provided in order to print the URL of uploaded files.

Open up the entrypoint defining your web interface, such as `MyAppWeb`, and
add the line below into the `view` function's `quote` block.

```elixir
def view do
  quote do
    # some code
    import Uploader.HTML.UploadHelpers
  end
end
```

The helper below prints the URL for an uploaded file:

```elixir
<%= upload_url(user, :avatar_image) %>
```

You may also prepend the URL with a base URL:

```elixir
<%= upload_url(user, :avatar_image, base_url: upload_path()) %>
```

## Field options

The `uploadable_field/2` macro may optionally receive options to alter the way
`Plug.Upload` structs are casted, how filenames are generated, etc. Here is a
list of options:

* `:cast`: a function that casts a `Plug.Upload` struct into the value to be
stored in the database.
* `directory`: the base directory containing the file uploads.
* `filename`: a function that generates the filename based on the given struct.
* `on_file_exists`: specifies the strategy to apply if the file path already
exists. Its value may be:
    * `:overwrite`: overwrite the file if the file path already exists
    * `:compare_hash`: do not copy the file if the file path already exists;
    if the hashes of the files' content are not equal, return an error.
* `print`: a function that prints the field (typically used be the view).
* `type`: the field type.

### Example case for custom options

A CMS allows the upload of a blog post's cover image. The blog post is available
in multiple languages and the cover image must be stored multiple times in
different languages for SEO purposes.

For example, the cover image for my post about my favorite books must have the
name "my-favorite-books.jpg" in English, "mes-livres-preferes.jpg" in French,
etc. We should then store all the images' filenames and retrieve the right filename
according to the language used by the reader.

The image upload (`Plug.Upload`) must be casted into a map of filenames in
different languages:

```elixir
%{
  "en" => "my-favorite-books.jpg",
  "fr" => "mes-livres-preferes.jpg",
  "nl" => "mijn-lievelingsboeken.jpg"
}
```

We want those filenames to have the same name as the post's URL slug (which are
held by another Schema field `:slug`) with the file extension appended. I.e. if
the English URL slug for that post is `my-favorite-books`, the cover image will
be named `my-favorite-books.jpg` in English.

Below are the Schema fields with the custom options to make that work.

The code below uses the `translatable_field/1` macro from the `i18n_helpers`
package. A translatable field holds a map of values for different languages
as the map shown above, and generates a virtual field (field prepended by
"translated_") holding the translated field. For example the `:slug` field
may contain a map such as `%{"en" => "favorite-books", "fr" => "livres-preferes"}`
and `:translated_slug` will contain `livres-preferes` if the struct has been
translated in French. See `i18n_helpers`'s readme.

```elixir
translatable_field :slug
translatable_field :cover_image

uploadable_field :cover_image,
  cast: &User.cast_cover_image/2,
  directory: @uploads_directory,
  filename: &User.filename_cover_image/2,
  on_file_exists: :compare_hash,
  print: &User.print_cover_image/2,
  type: :map
```

```elixir
# Cast the Plug.Upload struct into a map of filenames per language.

def cast_cover_image(
      %Plug.Upload{filename: uploaded_filename},
      %Ecto.Changeset{} = changeset
    ) do
  slugs = fetch_field!(changeset, :slug)
  extension = Path.extname(uploaded_filename) |> String.downcase()
  Enum.map(slugs, fn {language, slug} -> {language, slug <> extension} end) |> Enum.into(%{})
end

# Return the list of filenames to be stored.

def filename_cover_image(%User{cover_image: cover_image}, _field_name) do
  Map.values(cover_image)
end

# Return the filename to be printed.

def print_cover_image(%User{translated_cover_image: translated_cover_image}, _field_name) do
  translated_cover_image
end
```

## Installation

Add `uploader` for Elixir as a dependency in your `mix.exs` file:

```elixir
def deps do
  [
    {:uploader, "~> 0.1.0"}
  ]
end
```

## HexDocs

HexDocs documentation can be found at [https://hexdocs.pm/uploader](https://hexdocs.pm/uploader).
