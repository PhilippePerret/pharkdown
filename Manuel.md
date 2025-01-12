# Pharkdown

## Présentation

**Pharkdown** est un *engin de rendu* pour [Phoenix/Elixir](https://elixir-lang.org/docs.html) qui permet de travailler ses vues à partir d'un formatage simple, à l'image de [markdown](https://fr.wikipedia.org/wiki/Markdown) mais offrant beaucoup plus de possibilités. On peut notamment créer des *environnements* personnalisés pour traiter un bloc de texte d'une manière personnalisées.

En plus de ça, *pharkdown* opère tout un tas de transformation qui permettent de simplifier la vie et d'assurer un rendu parfait (notamment en gérant, de façon unique, les espaces insécables qui ne sont jamais parfaitement rendu).

### Compile time et Runtime

Une autre grande différence, dans l'utilisation avec Phoenix, est que *Pharkdown* fonctionne en deux temps. Il peut fonctionner en direct (avec la méthode `render/3` de Phoenix) et il peut fonctionner en préparant à la compilation un document `.html.heex` qui sera ensuite utiliser avec `render/3`. Le second fonctionnement est le fonctionnement "normal".

Pour ce faire, il suffit d'ajouter `use Pharkdown` au contrôleur qui doit utiliser cette possibilité.

## Utilisation

### Transformations automatiques

#### Espaces insécables

Malgré tous les efforts des navigateurs, ils ne parviennent pas à traiter correctement les insécables et on se retrouve souvent avec des ":" ou autres "!" tout seuls à la ligne. Il n'en va pas de même avec *Pharkdown* qui les gèrent parfaitement.

### Marquages spéciaux

#### Exposant avec `^`

Pour placer les 2^e ou 1^er, ou les notes^12, on utilise le circonflexe avant l'élément à mettre en exposant. Par exemple :

~~~
Le 1^er et la 2^e comme la 1^re et le 2^e.
~~~

Pharkdown procède ici à des corrections automatiques (sauf si les options sont réglées à `correct: false`) dont la liste est la suivante :

~~~
2^ème => "ème" fautif remplacé par "e"
1^ere => "ere" fautif remplacé par "re"
e après X, V, I ou un nombre comme dans XIXe ou 54e => e en exposant
~~~

Pour que ces corrections ne s'effectuent pas, mettre les options à `correct: false`. Seul le circonflexe sera traité en tant que marque d'exposant. Le texte `1\^ère` fautif restera `1<sup>ère</sup>` (par exemple dans un cours d'orthographe).

### Substitutions

### Liens `[...](...)`

Comme avec markdown, on peut utiliser le formatage `[titre](href)` pour créer des liens. Mais on peut aller plus loin en ajoutant après `href` des valeurs d'attributs à ajouter à la balise `<a>`. Tous les attributs doivent être séparés par des virgules (virgule-espace) et chaque élément doit être une paire `attribut=value` qui sera transformée en `attribut="value"` (ne pas mettre de guillemets, donc).

~~~~
[titre](path/to/ca) # => "<a href="path/to/ca">titre</a>"

[titre](path/to | class=css1 css2, style=margin-top:12rem;)
=> "<a href="path/to" class="css1 css2" style="margin-top:12rem;">titre</a>
~~~~

#### Guillemets droits

Les guillemets droits (") sont automatiquement remplacés par des chevrons et les apostrophes droits par des apostrophes courbes, sauf si l'option `[smarties: false]` est utilisées.

Noter que cela n'affecte en rien les codes mais seulement les textes (sauf dans les codes, où il faut penser à les utiliser directement).

#### Retours à la ligne

On peut forcer un simple retour à la ligne (`<br />` en HTML) en utilisant `\n`. Par exemple :

~~~
Le texte avec un \n Retour à la ligne
~~~

### Les lignes

Contrairement à Markdown — et c'est une des grandes différences —, on ne sépare par les paragraphes par des doubles-retours chariot. Ainsi, le texte :

~~~
Mon paragraphe
Mon deuxième paragraphe
~~~

… sera interprété comme deux paragraphes distincts.

Quand on doit vraiment forcément un retour à la ligne, on ajoute un `\n` avant d'écrire le paragraphe en dessous ou à la suite. Par exemple, le texte :

~~~
Mon paragraphe \n Avec un autre à la ligne
~~~

… ou 

~~~
Mon paragraphe \n
avec un autre à la ligne
~~~

… seront considéré comme des textes dans le même paragraphe mais auquel on ajoutera un `<br />` pour forcer le passage à la ligne.

## Les environnements

Il existe des *environnements* par défaut qui permettent de mettre en forme le texte d'une certaine manière. C'est le cas par exemple pour du code ou un aspect document pour du texte.

Un environnement se trouve entre les marques :

~~~
environnement/
...
/environnement
~~~

Ces environnements sont :

~~~
document (ou 'doc')
blockcode (ou 'code' ou 'bcode')
~~~

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
