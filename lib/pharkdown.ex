defmodule Pharkdown do
  @moduledoc """
  Documentation for `Pharkdown`.
  """

  defmacro __using__(_options) do
    IO.puts "-> Je passe par __using__"
    IO.puts "Appelé par #{inspect __CALLER__}"
    # IO.inspect(options, label: "Options dans __using__")

    quote do
      IO.puts "On utilise mon module."
      def hello2 do
        IO.puts "Hello depuis Phrarkdown"
      end
    end
  end

end
