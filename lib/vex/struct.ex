defmodule Vex.Struct do
  @moduledoc false

  defmacro __using__(opts) do
    quote do
      @vex_validations %{}
      @precompile_validator_lookup unquote(Keyword.get(opts, :precompile_validator_lookup, false))
      @precompile_sources unquote(Keyword.get(opts, :precompile_sources, [Vex.Validators]))
      @precompiled_validator_lookup %{}
      @before_compile unquote(__MODULE__)
      import unquote(__MODULE__)
      def valid?(self), do: Vex.valid?(self)
    end
  end

  defmacro __before_compile__(_) do
    quote do
      def __vex_validations__(), do: @vex_validations

      if @precompile_validator_lookup do
        def __vex_validator__(name) do
          {:ok, Map.fetch!(@precompiled_validator_lookup, name)}
        end
      else
        def __vex_validator__(_name), do: {:error, :not_enabled}
      end

      require Vex.Extract.Struct
      Vex.Extract.Struct.for_struct()
    end
  end

  defmacro validates(name, validations \\ []) do
    quote do
      @vex_validations Map.put(@vex_validations, unquote(name), unquote(validations))
      if @precompile_validator_lookup do
        @precompiled_validator_lookup Enum.reduce(
                                        unquote(validations) |> List.wrap(),
                                        @precompiled_validator_lookup,
                                        fn
                                          {validator_name, _validator_opts}, lookup ->
                                            Map.put_new_lazy(
                                              lookup,
                                              validator_name,
                                              fn ->
                                                IO.puts("Going to use the validator here?")

                                                case Vex.validator(
                                                       validator_name,
                                                       @precompile_sources
                                                     ) do
                                                  nil ->
                                                    Vex.validator_error!(
                                                      validator_name,
                                                      @precompile_sources
                                                    )

                                                  found ->
                                                    found
                                                end
                                              end
                                            )

                                          fun, lookup when is_function(fun) ->
                                            Map.put_new_lazy(
                                              lookup,
                                              :by,
                                              fn ->
                                                case Vex.validator(:by, @precompile_sources) do
                                                  nil ->
                                                    Vex.validator_error!(:by, @precompile_sources)

                                                  found ->
                                                    found
                                                end
                                              end
                                            )
                                        end
                                      )
      end
    end
  end
end
