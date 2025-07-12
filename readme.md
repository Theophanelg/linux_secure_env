# Projet : Environnement Sécurisé Chiffré

Ce projet fournit un ensemble de scripts Bash pour créer, gérer et utiliser un environnement sécurisé chiffré. Il vous permet de stocker des données sensibles, de gérer des clés GPG et des configurations SSH au sein d'un conteneur chiffré par LUKS.

## Table des Matières

    - Fonctionnalités

    - Prérequis

    - Structure du Projet

    - Installation et Utilisation

        - Installation de l'Environnement

        - Ouverture de l'Environnement

        - Fermeture de l'Environnement

        - Gestion des Clés GPG

        - Gestion des Configurations SSH

        - Définir les Permissions de Sécurité

    - Dépannage Courant

## 1. Fonctionnalités

Ce projet offre les capacités suivantes :

- Création d'un conteneur chiffré : Met en place un fichier de 5 Go (modifiable) chiffré avec LUKS et formaté en Ext4.

- Gestion de l'accès : Permet d'ouvrir et de fermer l'environnement sécurisé facilement.

- Cryptographie GPG :

        - Création automatisée de paires de clés GPG directement dans le coffre.

        - Importation de clés GPG (publiques et privées) du coffre vers votre trousseau GPG local.

        - Exportation de clés GPG (publiques et privées) de votre trousseau GPG local vers le coffre.

- Gestion des configurations SSH :

        - Création d'un fichier de configuration SSH modèle (config) dans le coffre, utilisable avec ssh -F.

        - Configuration d'un alias evsh pour simplifier l'utilisation du ssh -F avec le coffre.

        - Importation intelligente des configurations et clés SSH existantes depuis votre ~/.ssh/config vers le coffre, avec ajustement des chemins de clés.

- Permissions de sécurité : Applique automatiquement les permissions 700 (accès propriétaire seulement) aux répertoires sensibles et 600 aux fichiers de clés privées dans le coffre.

## 2. Prérequis

Avant d'utiliser ce projet, assurez-vous que les outils suivants sont installés sur votre système Debian (ou distribution similaire) :

    - bash : Le shell d'exécution.

    - sudo : Pour exécuter des commandes avec des privilèges root (nécessaire pour la gestion du chiffrement et des montages).

    - cryptsetup : Pour le chiffrement LUKS.

        - Installation : sudo apt install cryptsetup

    - e2fsprogs : Fournit mkfs.ext4 pour le formatage.

        - Installation : sudo apt install e2fsprogs

    - fallocate : Pour la pré-allocation de l'espace disque.

        - Installation : sudo apt install util-linux (souvent déjà installé)

    - gnupg : Pour la gestion des clés GPG.

        - Installation : sudo apt install gnupg

    - cowsay et figlet : Pour des messages amusants (optionnels, mais recommandés pour l'expérience utilisateur).

        - Installation : sudo apt install cowsay figlet

    - awk, cut, grep, sed, basename, dirname, realpath, getent : Outils de ligne de commande standards (généralement déjà installés).

## 3. Structure du Projet

Le projet doit avoir la structure de répertoires suivante :
```bash
.
├── main.sh
├── lib/
│   ├── cryptogpg.sh
│   ├── install.sh
│   ├── setup.sh
│   └── ssh_config_manager.sh
├── config/
│   └── alias.sh
└── secure_env_data/
    └── secure_container.img
```
## 4. Installation et Utilisation

Toutes les actions sont lancées via le script principal main.sh. Exécutez toujours main.sh avec sudo car il effectue des opérations système.

Naviguez vers le répertoire racine de votre projet dans le terminal :

    cd ~/Bureau/linux_secure_env # Ou le chemin où se trouve votre projet

### Installation de l'Environnement

Cette commande crée et initialise votre environnement sécurisé. Elle vous demandera un mot de passe pour le chiffrement et la taille du conteneur.

    sudo ./main.sh install

    - Suivez les invites : Entrez la taille souhaitée (ex: 5G, 10G), puis un mot de passe fort et confirmez-le.

    - Le script s'occupera de créer le fichier, de le chiffrer, de le formater et de définir les permissions initiales.

    - Si vous manquez d'espace disque, entrez une taille plus petite (ex: 1G).

### Ouverture de l'Environnement

Cette commande déverrouille et monte votre environnement sécurisé sur /mnt/secure_env.

    sudo ./main.sh open

    - Suivez l'invite : Entrez le mot de passe que vous avez défini lors de l'installation.

    - L'environnement sera monté sur /mnt/secure_env/.

### Fermeture de l'Environnement

Cette commande démonte et ferme votre environnement sécurisé. **Toujours fermer le coffre après utilisation.**

    sudo ./main.sh close

    - Si le coffre refuse de se démonter car il est "occupé", assurez-vous que votre terminal n'est pas dans un sous-répertoire de /mnt/secure_env (faites cd ~ ou cd chemin/vers/votre/projet), et qu'aucun autre processus n'utilise des fichiers à l'intérieur.

### Gestion des Clés GPG

Ces commandes vous permettent de gérer vos clés GPG en lien avec le coffre. L'environnement doit être ouvert pour toutes ces opérations.

    - Créer une nouvelle paire de clés GPG dans le coffre :

    sudo ./main.sh gpg_create

    - Suivez les invites (Nom d'utilisateur, Email, Commentaire). La clé sera stockée directement dans /mnt/secure_env/gpg_cles/.

- Importer les clés GPG du coffre vers votre trousseau local (root) :

    sudo ./main.sh gpg_import_vault

    - Ceci est crucial pour que les clés créées dans le coffre soient utilisables par gpg sur votre système.

- Exporter une clé publique de votre trousseau local vers le coffre :

    sudo ./main.sh gpg_export_pub

    - Suivez l'invite. La clé publique sera exportée de votre trousseau GPG local (/root/.gnupg) vers /mnt/secure_env/gpg_cles/.

- Exporter une clé privée de votre trousseau local vers le coffre :

- sudo ./main.sh gpg_export_priv

    - Attention : Soyez prudent avec la clé privée. Elle sera exportée de votre trousseau GPG local (/root/.gnupg) vers /mnt/secure_env/gpg_cles/.

- Exporter des clés GPG du coffre vers votre trousseau local (alternative à l'importation) :

    - sudo ./main.sh gpg_export_vault

        - Suivez l'invite. Permet d'exporter des clés spécifiques depuis le trousseau du coffre.

### Gestion des Configurations SSH

Ces commandes vous aident à sécuriser et gérer vos accès SSH. L'environnement doit être ouvert pour toutes ces opérations.

- Créer le template de configuration SSH et configurer l'alias evsh :

    sudo ./main.sh ssh_setup

    - Ceci créera /mnt/secure_env/ssh/config (le fichier de configuration SSH dans le coffre) et config/alias.sh (contenant l'alias evsh).

    - Action requise : Le script vous affichera une ligne à ajouter à votre ~/.bashrc (ou .zshrc) pour activer l'alias. Copiez-la et ajoutez-la à votre fichier de configuration de shell.

    - Après modification de ~/.bashrc, rechargez votre shell : source ~/.bashrc.

    - Vous pourrez alors utiliser evsh <nom_du_poste> pour vous connecter en utilisant la configuration SSH du coffre.

- Importer des configurations et clés SSH existantes dans le coffre :

    sudo ./main.sh ssh_import

        - Le script analysera votre ~/.ssh/config (le fichier de l'utilisateur qui exécute sudo ./main.sh). Il listera les hôtes trouvés et vous permettra de choisir lesquels importer dans le coffre, en copiant les clés correspondantes et en ajustant le chemin IdentityFile dans la configuration du coffre.

- Définir les Permissions de Sécurité

Cette commande applique les permissions 700 aux répertoires clés et 600 aux fichiers sensibles (clés privées) dans le coffre. Elle est exécutée automatiquement lors de l'installation et de l'ouverture, mais peut être lancée manuellement. L'environnement doit être ouvert pour cette opération.

    sudo ./main.sh set_permissions

5. Dépannage Courant

    - [ERREUR] Aucun espace disponible sur le périphérique :

        - Votre partition racine (/) est pleine. Vérifiez avec df -h.

        - Si vous avez agrandi le disque de votre VM, vous devez étendre la partition sda1 pour utiliser le nouvel espace. Utilisez sudo growpart /dev/sda 1 puis sudo resize2fs /dev/sda1. Redémarrez si nécessaire.

     - Le périphérique secure_env existe déjà ou la cible est active lors de open ou close :

       - Cela signifie que le périphérique chiffré est toujours actif ou qu'un processus l'utilise.

    - Assurez-vous que votre terminal n'est pas dans un sous-répertoire de /mnt/secure_env (faites cd ~).

        - Tentez de le fermer proprement : sudo ./main.sh close.

        - Si cela persiste, un processus gpg-agent peut le retenir. Redémarrez votre machine virtuelle (sudo reboot) pour nettoyer l'état.

    - Avertissement: Clé privée '/home/user/.ssh/id_rsa_test' non trouvée lors de ssh_import :

       - Vérifiez que le fichier de clé existe bien au chemin indiqué pour l'utilisateur qui a lancé sudo.

    - gpg: Attention : rien n'a été exporté :

        - Cela signifie que la clé recherchée n'était pas dans le trousseau GPG par défaut (celui de root si vous utilisez sudo). Utilisez sudo ./main.sh gpg_import_vault pour importer les clés du coffre vers votre trousseau système en premier.
