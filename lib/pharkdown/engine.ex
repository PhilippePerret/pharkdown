defmodule Pharkdown.Engine do
  @moduledoc """
  Engin de rendu pour le format Pharkdown (.phad).
  """

  @behaviour Phoenix.Template.Engine

  # Options par défaut
  @default_options [
    smarties: true, 
    correct:  true
  ]

  alias Pharkdown.{Loader, Parser, Formatter}

  @doc """
  Fonction principale, requise, pour produire le code AST permettant
  de rendre la page.
  """
  @impl true
  def compile(path, _filename, options \\ []) do
    # IO.inspect(path, label: "\nPATH in compile")
    # IO.inspect(options, label: "\nOPTIONS in compile")

    debugit = options[:debug] == true

    content = File.read!(path)
    options = compile_options(path, options)
    |> inspect("OPTIONS", debugit)

    quote do
      unquote(compile_string(content, options))
    end
  end

  @doc """
  Transforme le texte +string+, formaté en Pharkdown, en un texte 
  HTML conforme.
  """
  def compile_string(string, options \\ nil) when is_binary(string) do
    options = is_nil(options) && compile_options(nil, []) || options
    debugit = options[:dgb] == true
    options = [ {:debug, debugit} | options]
    # |> inspect("Options", debugit)
    string
    |> Loader.load_external_contents(options)
    |> inspect("After Loader.load_external_contents/2", debugit)
    |> Parser.parse(options)
    |> inspect("After Parser.parse/2", debugit)
    |> Formatter.formate(options)
    |> inspect("After Formatter.formate/2", debugit)
    |> Formatter.very_last_correction(options)
    |> inspect("After Formatter.very_last_correction/2", debugit)
  end

  defp inspect(contenu, titre, debug) do
    if debug do
      IO.inspect(contenu, label:  titre_exerg(titre))
    end
    contenu
  end
  defp titre_exerg(str), do: IO.ANSI.green() <> "\n#{str}\n" <> IO.ANSI.reset()


  # Crée le fichier +html_path+ à partir du fichier +phad_path+
  def compile_file(phad_path, html_path \\ nil) do
    html_path = ensure_html_path_from(phad_path, html_path)
    File.write!(html_path, compile(phad_path, Path.basename(html_path)))
  end
  
  def compile_file(phad_path, html_path, options) do
    html_path = ensure_html_path_from(phad_path, html_path)
    code = compile(phad_path, Path.basename(html_path))
    # Pour le moment, faire comme si le fichier se trouvait à la racine, puisque 
    # cette fonction est appelée pour construire le manuel en HTML
    code = options[:full_html] && full_html(code, options) || code
    File.write!(html_path, code)
  end

  defp full_html(html_code, options \\ []) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>#{options[:title] || "Page sans titre"}</title>
      #{options[:css]}
      <style type="text/css">
      body {
        margin: 1em 2em;
        width: 920px;
        padding: 0;
      }
      </style>
    </head>
    <body>
      #{html_code}
    </body>
    </html>
    """
  end

  defp ensure_html_path_from(phad_path, html_path) do
    if is_nil(html_path) do
      folder = Path.dirname(phad_path)
      affixe = Path.basename(phad_path, Path.extname(phad_path))
      Path.join([folder, "#{affixe}.html"])
    else
      html_path
    end
  end

  def compile_options(nil, options) do
    # Options du programmeur (config)
    app_options = Keyword.merge(
      @default_options, 
      Application.get_env(:pharkdown, :options, [])
    )
    # Compilation de toutes les options
    options ++ app_options
  end

  def compile_options(path, options) do
    # Options générales
    options = compile_options(nil, options)
    # Pour informations (débuggage et erreur)
    file_infos = [ path: path, fname: Path.basename(path) ]
    # Compilation de toutes les options
    options ++ file_infos
  end


end #/module Pharkdown.Engine