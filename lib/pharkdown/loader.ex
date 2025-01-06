defmodule Pharkdown.Loader do
  @moduledoc """
  Module chargé de charger (sic) tous les contenus externes
  """

  # TODO Le définir en configuration ?
  @load_external_file_options %{source: true}

  @regex_load ~r/load\((.*)\)/U
  @regex_load_as_code ~r/load_as_code\((.*)\)/U


  @doc """
  = main =
  Reçoit le code du fichier et y insert les codes chargés des fichiers externes
  """
  def load_external_contents(code, options) do
    code
    |> load_external_textes(options)
    |> load_external_codes(options)
  end

  defp load_external_textes(code, options) do
    Regex.replace(@regex_load, code, fn _tout, pseudo_path -> 
      case resolve_pseudo_path(pseudo_path, options) do
        {:ok, path}     -> 
          File.read!(path)
        {:error, error} -> 
          error
      end
    end)
  end

  def load_external_codes(code, options) do
    Regex.replace(@regex_load_as_code, code, fn _tout, pseudo_path ->
      case resolve_pseudo_path(pseudo_path, options) do
        {:ok, path}     -> 
          replace_as_code(path, options)
        {:error, error} -> 
          error
      end
    end)
  end


  defp replace_as_code(path, options) do
    extension = path |> String.split(".") |> Enum.fetch!(-1)
    langage = 
      case extension do
      "rb"    -> "ruby"
      "md"    -> "markdown"
      "ex"    -> "elixir"
      "heex"  -> "elixir component"
      "py"    -> "python"
      "js"    -> "javascript"
      _ -> extension # par exemple pour css
      end

    source = if @load_external_file_options[:source], do: "<span class=\"text-sm italic\">(source : #{path})</span>\n\n", else: ""
    
    # Code retourné
    """
    ~~~#{langage}
    #{source}#{File.read!(path)}
    ~~~
    """
  end

  # Function qui reçoit un pseudo path (qui peut se résumer au nom sans extension du fichier)
  # et retourne son path, c'est-à-dire le path d'un fichier existant
  #
  # @return {:ok, full_path} en cas de succès et {:error, <l'erreur>} dans le cas
  # contraire
  defp resolve_pseudo_path(ppath, options) do
    ppath = Path.extname(ppath) == "" && "#{ppath}.phad" || ppath
    cond do
    File.exists?(ppath) -> {:ok, ppath}
    options[:folder] && File.exists?(Path.join([options[:folder], ppath])) -> {:ok, Path.join([options[:folder], ppath])}
    File.exists?(fpath = Path.join(["priv","static","textes", ppath])) -> {:ok, fpath}
    options[:template_folder] && File.exists?(Path.join(options[:template_folder], ppath)) -> {:ok, Path.join(options[:template_folder], ppath)}
    true -> {:error, "[Impossible de résoudre le chemin de '#{ppath}']"}
    end
  end

end