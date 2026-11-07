# Application Android BASSARI-ZIK

Coquille Android : elle ouvre le site BASSARI-ZIK et permet de retrouver
automatiquement les fichiers audio du téléphone, après l'accord de l'utilisateur.

## Compiler (sur votre ordinateur)

1. Installez Android Studio.
2. Ouvrez le dossier `android/` (Open → sélectionnez le dossier).
3. Laissez Gradle télécharger les dépendances.
4. Menu Build → Build Bundle(s) / APK(s) → Build APK(s) pour un test,
   ou Generate Signed Bundle pour le Play Store.

## Avant publication

- Ajouter une icône : Android Studio → clic droit sur `app` → New → Image Asset,
  et choisir `icon-512.png` du site.
- Signer l'application avec une clé de publication (à conserver précieusement).
- Vérifier sur un vrai téléphone : permission, liste des morceaux, lecture.

## Fonctionnement

- Le site détecte l'objet `BzNative` et affiche la section « Musiques du téléphone ».
- Au premier lancement, l'application demande l'accès à la musique.
- `listAudio()` liste les morceaux, `readAudio(id)` renvoie leur contenu.

Cette version n'a pas été compilée dans l'environnement de préparation : une
première compilation peut révéler des ajustements mineurs.
