defmodule Pharkdown do
  @moduledoc """
  Documentation for `Pharkdown`.
  """

  # Pour savoir si le programme a été changé
  @last_pharkdown_modify_datetime  ["engine.ex", "formater.ex", "loader.ex","parser.ex"]
    |> Enum.reduce(%{datetime: ~U[2025-01-12 06:36:00.003Z]}, fn name, accu ->
      datetime = File.stat!(Path.join([".","lib","pharkdown", name]))
      accu = 
        if datetime > accu.datetime do
          %{ accu | datetime: datetime }
        else accu end 
    end)
    |> Map.get(:datetime)
    |> IO.inspect(label: "\n@last_pharkdown_modify_datetime")
  

  defp phad_files_in_folder(template_folder) do
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

  # Fonction qui analyse les fichiers .phad trouvés dans le dossier 
  # du module utilisant Pharkdown. Elle les classes en une Map :
  #   new:    [Nouveau fichier (n'ayant pas encore de fichier .html.heex)]
  #   mod:    [Fichiers avec .html.heex mais modifiés]
  #   oks:    [Fichiers avec .html.heex à jour]
  # 
  defp analyse_phad_files(phad_files) do
    phad_files
    |> Enum.reduce(%{new: [], mod: [], oks: []}, fn dfile, acc ->
      cond do
      !File.exists?(dfile[:html]) -> %{ acc | new: acc.new ++ [ dfile ] }
      (File.stat!(dfile[:html]).mtime < @last_pharkdown_modify_datetime) -> %{ acc | mod: acc.mod ++ [ dfile ] }
      (File.stat!(dfile[:html]).mtime < File.stat!(dfile[:phad]).mtime) -> %{ acc | mod: acc.mod ++ [ dfile ] }
      true -> %{acc | oks: acc.oks ++ [ dfile ] }
      end
    end)
    # |> IO.inspect(label: "Répartition des fichiers")
  end

  defp update_phad_files(phad_data) do
    Enum.each(phad_data.new, fn dfile ->
      IO.puts "Création du fichier HTML de #{dfile[:name]}"
      Pharkdown.Engine.compile_file(dfile[:phad], dfile[:html], dfile[:name])
    end)
    Enum.each(phad_data.mod, fn dfile ->
      IO.puts "Actualisation du fichier HTML de #{dfile[:name]}"
      File.rm(dfile[:html])
      Pharkdown.Engine.compile_file(dfile[:phad], dfile[:html], dfile[:name])
    end)
  end

  defmacro __using__(options) do
    IO.puts "-> Je passe par __using__"
    # IO.puts "Appelé par #{inspect __CALLER__}"
    # IO.inspect(options, label: "Options dans __using__")
    
    module = __CALLER__.module
    [template_folder, error_message] = 
      if options[:templates_folder] do
        [
          Path.expand(options[:templates_folder]),
          "Template folder #{options[:templates_folder]} could not be found."]
      else
        [
          String.replace(__CALLER__.file, ~r/_controller\.ex$/, "_html"),
          "Template folder for #{module} could not be found.\nUse 'use Pharkdown, templates_folder: path/to/folder' if you want to set an unconventional path."
        ]        
      end
    File.exists?(template_folder) || raise error_message

    # Établissement de la liste des fichiers .phad à reconstruire
    # et leur reconstruction.
    phad_files_in_folder(template_folder)
    |> analyse_phad_files()
    |> update_phad_files()

    quote do
      IO.puts "On utilise mon module."
      def hello2 do
        IO.puts "Hello depuis Phrarkdown"
      end
    end
  end

end
