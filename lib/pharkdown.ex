defmodule Pharkdown do
  @moduledoc """
  Documentation for `Pharkdown`.
  """
  # Pour savoir si le programme a été changé
  @last_pharkdown_modify_datetime  ["engine.ex", "formatter.ex", "loader.ex","parser.ex"]
    |> Enum.reduce(%{datetime: NaiveDateTime.new!(~D[2025-01-12], ~T[06:36:00])}, fn name, accu ->
      path = Path.expand(Path.join([".","lib","pharkdown", name]))
      # |> IO.inspect(label: "\nChemin absolu")
      {{year, month, day}, {hour, minute, second}} = File.stat!(path).mtime
      datetime = NaiveDateTime.new!(year, month, day, hour, minute, second)
      NaiveDateTime.after?(datetime, accu.datetime) && %{ accu | datetime: datetime } || accu
    end)
    |> Map.get(:datetime)
    |> IO.inspect(label: "\n@last_pharkdown_modify_datetime")
  

  def phad_files_in_folder(template_folder) do
    File.ls!(template_folder)
    |> Enum.filter(fn name -> Path.extname(name) == ".phad" end)
    |> Enum.map(fn name ->
      [
        {:name, name},
        {:phad, Path.join([template_folder, name])},
        {:html, Path.join([template_folder, Path.basename(name, Path.extname(name)) <> ".html.heex"])}
      ]
    end)
    # |> IO.inspect(label: "Pharkdown files")
  end

  defp mtime_to_naive_date_time(mtime) do
    {{year, month, day}, {hour, minute, second}} = mtime
    NaiveDateTime.new!(year, month, day, hour, minute, second)
  end

  # Fonction qui analyse les fichiers .phad trouvés dans le dossier 
  # du module utilisant Pharkdown. Elle les classes en une Map :
  #   new:    [Nouveau fichier (n'ayant pas encore de fichier .html.heex)]
  #   mod:    [Fichiers avec .html.heex mais modifiés]
  #   oks:    [Fichiers avec .html.heex à jour]
  # 
  def analyse_phad_files(phad_files) do
    # IO.puts "-> analyse_phad_files"
    phad_files
    |> Enum.reduce(%{new: [], mod: [], oks: []}, fn dfile, acc ->
      mtime_html = File.exists?(dfile[:html]) && mtime_to_naive_date_time(File.stat!(dfile[:html]).mtime)
      mtime_phad = mtime_to_naive_date_time(File.stat!(dfile[:phad]).mtime)
      cond do
      !File.exists?(dfile[:html]) -> %{ acc | new: acc.new ++ [ dfile ] }
      NaiveDateTime.before?(mtime_html, @last_pharkdown_modify_datetime) -> %{ acc | mod: acc.mod ++ [ dfile ] }
      NaiveDateTime.before?(mtime_html, mtime_phad)  -> %{ acc | mod: acc.mod ++ [ dfile ] }
      true -> %{acc | oks: acc.oks ++ [ dfile ] }
      end
    end)
    |> IO.inspect(label: "Répartition des fichiers")
  end
  
  def update_phad_files(phad_data) do
    Enum.each(phad_data.new, fn dfile ->
      # IO.puts "Création du fichier HTML de #{dfile[:name]}"
      Pharkdown.Engine.compile_file(dfile[:phad], dfile[:html])
    end)
    Enum.each(phad_data.mod, fn dfile ->
      # IO.puts "Actualisation du fichier HTML de #{dfile[:name]}"
      File.rm(dfile[:html])
      Pharkdown.Engine.compile_file(dfile[:phad], dfile[:html])
    end)
  end

  def add_css_file_to_project() do
    # this_app = Mix.Project.config()[:app] # |> IO.inspect(label: "L'application est ")
    app_folder = File.cwd!() # |> IO.inspect(label: "\nDOSSIER COURANT ?")
    app_css_path = Path.join([app_folder, "assets", "css", "app.css"]) # |> IO.inspect(label: "Path to app.css cherché")
    css_path = Path.join(Application.app_dir(:pharkdown, "priv/static/css"), "themes/pharkdown.css")

    # Ligne à ajouter au fichier app.css du projet
    import_line = """

    /* For Pharkdown — You can choose an other theme */
    @import \"#{css_path}\";
    
    """
    # |> IO.inspect(label: "\nLine pour CSS à ajouter")

    # Vérifie si la ligne est déjà présente
    # message =
      cond do 
      !File.exists?(app_css_path) -> "Fichier app.css introuvable… (#{app_css_path})"
      File.read!(app_css_path) |> String.contains?(import_line) -> "Code déjà présent dans le fichier."
      true ->
        File.write!(app_css_path, "#{import_line}\n", [:append])
        "Ligne ajoutée à app.css : #{import_line}"
      end    
    # IO.puts message

  end

  defmacro __using__(options) do
    IO.puts "-> Pharkdown.__using__"
    path_folder_html = String.replace(__CALLER__.file, ~r/_controller\.ex$/, "_html")
  
    quote bind_quoted: [options: options, path_folder_html: path_folder_html] do
      # Détermine le dossier des templates .phad
      template_folder =
        if options[:templates_folder] do
          Path.expand(options[:templates_folder])
        else
          path_folder_html
        end
  
      File.exists?(template_folder) || raise "Template folder not found: #{template_folder}"
  
      # On met le fichier CSS
      Pharkdown.add_css_file_to_project()

      defp check_and_update_phad_files do
        # IO.inspect("Vérification et génération des fichiers...")
        Pharkdown.phad_files_in_folder(unquote(template_folder))
        |> Pharkdown.analyse_phad_files()
        |> Pharkdown.update_phad_files()
      end
  
      # Plug pour vérifier les fichiers avant chaque requête
      def call(conn, opts) do
        check_and_update_phad_files()
        super(conn, opts) # Assure que la connexion continue vers l'action prévue
      end
    end
  end


end
