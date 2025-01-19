# Pharkdown

## Présentation

**Pharkdown** est un *engin de rendu* pour [Phoenix/Elixir](https://elixir-lang.org/docs.html) qui permet de travailler ses vues à partir d'un formatage simple, à l'image de [markdown](https://fr.wikipedia.org/wiki/Markdown) mais offrant beaucoup plus de possibilités. On peut notamment créer des *environnements* personnalisés pour traiter un bloc de texte d'une manière personnalisées.

En plus de ça, *pharkdown* opère tout un tas de transformation qui permettent de simplifier la vie et d'assurer un rendu parfait (notamment en gérant, de façon unique, les espaces insécables qui ne sont jamais parfaitement rendu).

### Compile time et Runtime

Une autre grande différence, dans l'utilisation avec Phoenix, est que *Pharkdown* fonctionne en deux temps. Il peut fonctionner en direct (avec la méthode `render/3` de Phoenix) et il peut fonctionner en préparant à la compilation un document `.html.heex` qui sera ensuite utiliser avec `render/3`. Le second fonctionnement est le fonctionnement "normal".

Pour ce faire, il suffit d'ajouter `use Pharkdown` au contrôleur qui doit utiliser cette possibilité.

## Utilisation

### Code EEx et composants HEX

On peut, dans une page Pharkdown, utiliser les composants HEX (définis par `<.composant />`) ainsi que les codes `<%= operation %>`, qui ne seront qu'évalués au moment du chargement de la page (`render/3`).

Noter que les textes ou autres produits par les code EEx ne passent pas par les formateurs *Pharkdown* à part s'ils sont appelés explicitement. On peut faire par exemple : 

~~~
defmodule MonAppWeb.PageController do
  use MonAppWeb, :controller

  alias Transformer, as: T

  def home(conn, params) do
    render(conn, :home, %{
      message: "Mon <message> !" |> T.h()  # => "Mon <message>&amp;nbsp;!
    })
  end
end
~~~

Noter, ci-dessus, que c'est idiot de faire ça puisque les textes donnés sont interprétés pour du HTML donc il y a double interprétation ici, ce qui produit le `&amp;nbsp;` (la méthode `T.h/1` produit `&nbsp;` à la place de l'insécable et Phoenix remplace sont `&` par un `&amp;`.
Mais cela serait tout à fait justifié en utilisant : 

~~~
C'est <%= raw @message %>
~~~

… qui permet de traiter du code HTML tel quel.

> Rappel : Si des codes doivent être évalués (définitivement) à la compilation du fichier (transformation `.phad -> .html.heex`) il faut utiliser les [fonctions de transformation](#fonctions-transformation).

### Transformations automatiques

#### Espaces insécables

Malgré tous les efforts des navigateurs, ils ne parviennent pas à traiter correctement les insécables et on se retrouve souvent avec des ":" ou autres "!" tout seuls à la ligne. Il n'en va pas de même avec *Pharkdown* qui les gèrent parfaitement.

### Marquages spéciaux

#### Exposant avec `^`

Pour placer les 2^e ou 1^er, ou les notes^12, on utilise le circonflexe avant l'élément à mettre en exposant. Par exemple :

~~~
Le 1^er et la 2^e comme la 1^re et le 2^e.
~~~

Pharkdown procède ici à des corrections automatiques (sauf si les [options](#options) sont réglées à `correct: false`) dont la liste est la suivante :

~~~
2^ème => "ème" fautif remplacé par "e"
1^ere => "ere" fautif remplacé par "re"
e après X, V, I ou un nombre comme dans XIXe ou 54e => e en exposant
~~~

Pour que ces corrections ne s'effectuent pas, mettre les [options](#options) à `correct: false`. Seul le circonflexe sera traité en tant que marque d'exposant. Le texte `1\^ère` fautif restera `1<sup>ère</sup>` (par exemple dans un cours d'orthographe).


### Liens `[...](...)`

Comme avec markdown, on peut utiliser le formatage `[titre](href)` pour créer des liens. 

Mais on peut aller plus loin en utilisant le concept de *routes vérifiées* de Phoenix. il suffit pour ça de mettre le chemin relatif entre crochets :

~~~
[titre du lien]({vers/route/verifiee})
~~~

Ce marquage sera transformé en :

~~~html
<a href={~p"/vers/route/verfiee"}>
~~~

* Noter que le "/" manquant au début a été ajouté automatiquement.
* Noter qu'il ne faut surtout pas de guillemets dans les parenthèses, même après le `~p` s'il est utilisé : `[lien]({~p/path/to/verified})`

Mais on peut aller encore plus loin en ajoutant après `href` des valeurs d'attributs à ajouter à la balise `<a>`. Tous les attributs doivent être séparés par des virgules (virgule-espace) et chaque élément doit être une paire `attribut=value` qui sera transformée en `attribut="value"` (ne pas mettre de guillemets, donc).

~~~~
[titre](path/to/ca) # => "<a href="path/to/ca">titre</a>"

[titre](path/to | class=css1 css2, style=margin-top:12rem;)
=> "<a href="path/to" class="css1 css2" style="margin-top:12rem;">titre</a>
~~~~

#### Guillemets droits

Les guillemets droits (") sont automatiquement remplacés par des chevrons et les apostrophes droits par des apostrophes courbes, sauf si l'option `[smarties: false]` est utilisées.

Noter que cela n'affecte en rien les codes mais seulement les textes (sauf dans les codes, où il faut penser à les utiliser directement).

Si l'on veut forcer l'utilisation ponctuelle de guillemets droits, on peut forcer la marque avec `{{GL}}`.

#### Retours à la ligne

On peut forcer un simple retour à la ligne (`<br />` en HTML) en utilisant `\n`. Par exemple :

~~~
Le texte avec un \n Retour à la ligne
~~~

Note : les espaces autour du `\n` seront toujours supprimées.

### Sauts de ligne

Contrairement à Markdown — et c'est une des grandes différences —, on ne sépare pas les paragraphes par des doubles-retours chariot. Ainsi, le texte :

~~~
Mon paragraphe
Mon deuxième paragraphe
~~~

… sera interprété comme deux paragraphes distincts.

Quand on doit vraiment forcément un retour à la ligne, on ajoute un `\n` comme on l'a vu précédemment.

### Lignes de séparation

Comme en *Markdown*, on peut écrire les lignes en *Pharkdown* à l'aide de `---` (ou `***` ici) quand ce signe se trouve seul sur une ligne.

Mais avec *Pharkdown*, on peut styliser cette ligne :

* Avec du style brut. Par exemple `---height:10px---` produira la ligne `<hr style="height:10px"/>`.
* Avec du style par Map (ou Json). Par exemple `***%{height: "12px", size: "50%"}***` produira la ligne `<hr style="height:12px;size:50%;"/>`.
* Par classes CSS. Par exemple `---.css1.css2---` produira la ligne `<hr class="css1 css2"\>`.


## Stylisation

Une des grandes forces de Pharkdown par rapport à Markdown est de pouvoir styliser les paragraphes de façon simple, avec des classes CSS propres, et de pouvoir définir des identifiants afin d'y faire référence en CSS.

Ces classes et ces identifiants sont simplement définies en début de paragraphe, par un texte qui ne doit contenir que des lettres, des points, des tirets et des nombres. Il 

~~~
#monPar.css1.css2.en_core: Le paragraphe sera dans le style (class) css1, css2 et encore et aura pour identifiant '#monPar`.
~~~

Le code ci-dessus produira : 

~~~
<p id="monPar" class="css1 css2 en_core">Le paragraphe sera dans le style (class) css1, css2 et encore et aura pour identifiant '#monPar`.</p>
~~~

On peut même stipuler explicitement la balise à utiliser en la mettant en tout premier, sans point :

~~~
p#monDiv: C'est un "vrai" paragraphe, pas un div.
~~~

… produira :

~~~
<p id="p monDiv">C'est un div et pas un paragraphe.</p>
~~~

Il est impératif de mettre toujours dans l'ordre `tag-identifiant-classes css`.

## Les environnements

Il existe des *environnements* par défaut qui permettent de mettre en forme des blocs de texte d'une certaine manière. C'est le cas par exemple pour du code ou un aspect document pour du texte.

Un environnement se trouve entre les marques :

~~~
~environnement
...
environnement~
~~~

Ces environnements sont :

~~~
document (ou 'doc')
dictionary (ou 'dict' ou 'dico' ou 'dictionnaire')
~~~

> Voir le détail plus bas.

À l'avenir, l'utilisateur pourra définir le traitement de ses propres environnements.

### Listes

Comme en markdonw, on indique les liste à l'aide de `*` ou de `-` suivis d'une espace. Les degrés différents s'indiquent en multipliant ces marques.

~~~
* Item 1
** Item 1.1
** Item 1.2
* Item 2
~~~

On peut ajouter tout environnement à l'intérieur d'une liste, sans l'amorce :

~~~
* Item 1
** Item 1.1
doc/
Mon document qui sera placé dans l'item
de numéro 1.1 c'est-à-dire au second
niveau de plan.
/doc
** Item 1.2
* Item 2
~~~

Les listes numérotées s'indique avec un premier élément `1-` suivi d'une espace.

~~~
1- Item de liste numérotée
- Son item 2
etc.
~~~

On peut partir d'un autre chiffre sans problème :

~~~
233- Item d'une longue liste
- son deuxième item
etc.
~~~

### Dictionnaire (liste de définitions)

Permet d'avoir des textes qui se présentent de cette manière, avec un terme et une définition.

~dico
:Terme
Définition
Autre paragraphe définition
:Autre terme
.exergue: Définition dans le style exergue.
dico~

… en les définissant ainsi :

~~~
~dico
:Terme
Définition
Autre paragraphe définition
:Autre terme
.exergue: Définition dans le style exergue.
dico~
~~~

#### Classes CSS dans les thèmes
`dl` (liste de dictionnaire), `dt` (terme), `dd` (définition).

### Environnement document

~~~
~document
Un paragraphe de document.
Un autre paragraphe de document.
document~
~~~

{TODO: Décrire ce que cet environnement a de spécial…}

<a name="options"></a>

### Options

Pour définir les options, ajouter au fichier `config/config.ex` la ligne suivante :

~~~elixir
config :pharkdown, :options, [
  ... liste des options ...
]
~~~

Les options sont les suivantes :

~~~
smarties      Si true (default), corrige les guillemets, les appos-
              trophes.
correct       Si true (default), corrige certaines fautes comme les
              mauvais exposants, les insécables oubliés, etc.
debug         Si true, affiche des messages de déboguage (faux par
              défaut)
~~~

<a name="fonctions-transformation"></a>

### Fonctions de transformation

Une des fonctionnalités puissante de *Pharkdown* est de pouvoir utiliser des fonctions elixir pour insérer du code. Ces fonctions permettent donc de produire du code à la compilation du fichier `.phad`, au moment de sa transformation vers un fichier `.html.heex`.

Il existe deux types de fonction :

* Le type "normal", qui est évalué en début de traitement et permet donc d'insérer du code `.phad` qui sera traité comme tout contenu du fichier.
* Le type "post" qui sera évalué à la toute fin de la transformation et ne sera donc pas traité comme le reste du contenu. On identifie ces fonctions (le moins courantes, dans une utilisation normale) à l'aide du préfixe `post/`. Par exemple `post/ma_fonction_apres()`.

Ces fonctions doivent toutes être définies dans un module `Pharkdown.Helpers` accessible (donc placé quelque part dans le dossier `lib` de l'application). On la définit comme une fonction normale qui a accès à tous les éléments de l'application.

~~~elixir
defmodule Pharkdown.Helpers do

  def mafonction(arg1, arg2… argN) do
    ... traitement ...
    "sortie de la fonction" # à inscrire dans le document
  end

  def autre_fonction() do
    ...
  end

  def une_fonction_post(arg1… argN) do
    ...
  end
end
~~~

Le **nom d'une fonction** est impérativement construit avec des minuscules et des traits plats, rien d'autre.

Les arguments sont évalués à l'aide de l'extension `StringTo` (`StringTo.list`) et peuvent donc ne pas comporter de guillemets. Par exemple :

~~~
dit([bonjour, tout, le, monde])
~~~

… sera interprété comme : 

~~~elixir
dit(["bonjour", "tout", "le", "monde"])
~~~

Attention : si les arguments contiennent des virgules qu'il faut garder, il faut les échapper :

~~~
dit(Bonjour\, ça va ?)
~~~

Dans le cas contraire, *pharkdown* pensera qu'il s'agit de deux paramètres, "Bonjour" et "ça va ?".

C'est important pour des listes dans une suite de paramètres :

~~~
dit(Sais-tu jouer à, [1\, 2\, 3], soleil)
~~~

Ci-dessus, la fonction `dit` recevra : 

~~~
dit("Sais-tu jouer à", [1, 2, 3], "soleil")
~~~
