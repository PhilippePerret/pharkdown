### Les lignes

Contrairement à Markdown, on ne sépare par les paragraphes par des doubles-retour chariot. Ainsi, le texte :

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

### Listes

On indique les liste à l'aide de `*` ou de `-` suivis d'une espace. Les degrés différents s'indiquent en multipliant ces marques.

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
