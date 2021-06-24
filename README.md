## Description
Permet de créer un nouvelle route au niveau de l'API REST de koha pour exposer la disponibilité des exemplaires en temps réel. Utile pour un interfaçage avec un outil de découverte.
Ce plugin est prévu pour un environnement unimarc.
(Pour les périodiques, ces sont les états de collection, les abonnements et derniers numéros reçus qui sont exposée).

## Exemple de requête

Method:	
GET
URL: api/v1/contrib/rta/biblio/{biblionumber}


## Déploiement
Pour déployer le plugin, executez le script `build.sh`
```
user$ bash build.sh
```
Il va générer une archive kpz dans le répertoire kpz. Vous n'avez plus qu'à l'uploader dans la section Plugin de votre instance Koha
## Changement de version
Pour incrémenter le numéro de version du plugin, modifiez la valeur `VERSION` fichier `package.sh` avant de générer le .kpz.
