defmodule Uploader.Ecto.UploadableFields do
  @moduledoc ~S"""
  Provides a macro for defining uploadable fields.

  When calling `uploadable_field/2`, two fields are created:

    * a virtual field is created named by the given name prefixed by "uploaded_"
    and holds the `Plug.Upload` struct (representing the uploaded file).
    * a field with the given name is created holding the casted `Plug.Upload` struct
    (typically the struct is casted into a filename).

    The code below

      ```elixir
      uploadable_field :image
      ```

    will generate

      ```elixir
      field :image, :string
      field :uploaded_image, :any, virtual: true
      ```

  Using this module (`use`) provides the caller module with the function
  `get_uploadable_fields\0` listing all the uploadable fields and their options.

  The following options may be given to uploadable fields:

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
  """

  @callback get_uploadable_fields() :: [atom]

  defmacro __using__(_args) do
    this_module = __MODULE__

    quote do
      @behaviour unquote(this_module)

      import unquote(this_module),
        only: [
          uploadable_field: 2
        ]

      Module.register_attribute(__MODULE__, :uploadable_fields, accumulate: true)

      @before_compile unquote(this_module)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def get_uploadable_fields(), do: @uploadable_fields
    end
  end

  defmacro uploadable_field(field_name, opts \\ []) do
    field_type = Keyword.get(opts, :type, :string)

    quote do
      fields = Module.get_attribute(__MODULE__, :struct_fields)

      unless List.keyfind(fields, unquote(field_name), 0) do
        field(unquote(field_name), unquote(field_type))
      end

      field(String.to_atom("uploaded_" <> Atom.to_string(unquote(field_name))), :any,
        virtual: true
      )

      Module.put_attribute(
        __MODULE__,
        :uploadable_fields,
        {unquote(field_name), unquote(opts)}
      )
    end
  end
end
