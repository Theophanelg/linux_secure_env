#!/bin/bash

: "${MOUNT:=/mnt/secure_env}"
SSH_COFFRE_DIR="$MOUNT/ssh"
SSH_CONFIG_COFFRE="$SSH_COFFRE_DIR/config"
SSH_ALIAS_FILE="$SCRIPT_DIR/config/alias.sh"

creation_ssh_config_template(){
    echo "--- Création du fichier de configuration SSH template ---"
    if ! mountpoint -q "$MOUNT"; then
        echo -e "$ERREUR l'environnement sécurisé n'est pas monté $MOUNT"
        exit 1
    fi

    mkdir -p "$SSH_COFFRE_DIR" || {
        echo -e "$ERREUR impossible de créer le repertoire $SSH_COFFRE_DIR"
        exit 1
    }

    if [ ! -f "$SSH_CONFIG_COFFRE" ]; then
        echo "Création du fichier de configuration SSH template dans le coffre : $SSH_CONFIG_COFFRE"
        cat <<EOF > "$SSH_CONFIG_COFFRE"
# Fichier de configuration template SSH
# Utilisation: ssh -F /mnt/secure_env/ssh/config <nom_du_poste>
# Exemple de configuration de poste:
# Host mon-serveur
#  HostName 192.168.1.100
#  User monutilisateur
#  Port 22
#  IdentityFile %Chemin_du_COFFRE%/id_rsa_de_mon_serveur
#  StrictHostKeyChecking no
#  UserKnownHostsFile /dev/null
EOF
        if [ $? -ne 0 ]; then
            echo -e "$ERREUR Echec de la création du template SSH dans le coffre."
            exit 1
        fi
        chmod 600 "$SSH_CONFIG_COFFRE"
    else
        echo "Le fichier de configuration SSH existe déjà dans le coffre : $SSH_CONFIG_COFFRE"
        echo "Veuillez le modifier manuellement si nécessaire."
    fi
}

configuration_aliases() {
    echo "--- Configuration du fichier d'alias ---"

    if ! mountpoint -q "$MOUNT"; then
        echo -e "$ERREUR l'environnement sécurisé n'est pas monté $MOUNT"
        exit 1
    fi

    ALIAS_DIR="$(dirname "$SSH_ALIAS_FILE")"
    mkdir -p "$ALIAS_DIR" || {
        echo -e "$ERREUR Impossible de créer le répertoire d'alias : $ALIAS_DIR"
        exit 1
    }

    ALIAS_CONTENT="alias evsh=\"ssh -F $SSH_CONFIG_COFFRE\""

    echo "$ALIAS_CONTENT" > "$SSH_ALIAS_FILE" || {
        echo -e "$ERREUR Impossible d'écrire dans le fichier : $SSH_ALIAS_FILE"
        exit 1
    }

    echo "Fichier d'alias crée/mis à jour : $SSH_ALIAS_FILE"
    echo "Pour activer l'alias, rajoutez la ligne ci-dessous dans le ~/.bashrc"
    echo "source \"$(realpath "$SSH_ALIAS_FILE")\""
    echo "puis executez 'source ~/.bashrc'"
}

importation_ssh_config(){
    echo "--- Importation des configurations et clés SSH existantes"

    if ! mountpoint -q "$MOUNT"; then
        echo -e "$ERREUR L'environnement sécurisé n'est pas monté : $MOUNT"
        exit 1
    fi

    mkdir -p "$SSH_COFFRE_DIR" || {
        echo -e "$ERREUR Impossible de créer le répertoire $SSH_COFFRE_DIR"
        exit 1
    }

    # Récupérer le HOME de l'utilisateur qui a lancé sudo, de manière robuste
    ORIGINAL_USER_HOME="$SUDO_HOME"
    if [ -z "$ORIGINAL_USER_HOME" ] && [ -n "$SUDO_USER" ]; then
        ORIGINAL_USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    fi
    if [ -z "$ORIGINAL_USER_HOME" ]; then
        echo -e "$ERREUR Impossible de déterminer le répertoire personnel de l'utilisateur d'origine."
        exit 1
    fi

    UTILISATEUR_SSH_CONFIG="$ORIGINAL_USER_HOME/.ssh/config"

    SSH_CONFIG_COFFRE="$SSH_COFFRE_DIR/config"

    if [ ! -f "$UTILISATEUR_SSH_CONFIG" ]; then
        echo "Aucun fichier de configuration SSH trouvé à $UTILISATEUR_SSH_CONFIG"
        return 0
    fi

    echo "Analyse du fichier $UTILISATEUR_SSH_CONFIG"

    mapfile -t HOSTS < <(awk '/^Host / {print $2}' "$UTILISATEUR_SSH_CONFIG")

    if [ ${#HOSTS[@]} -eq 0 ]; then
        echo "Aucun hôte trouvé dans $UTILISATEUR_SSH_CONFIG"
        return 0
    fi

    echo "Hôtes disponibles :"
    for i in "${!HOSTS[@]}"; do
        echo "  $((i+1)). ${HOSTS[$i]}"
    done # <--- La ligne corrigée se termine ici, le `K` a été retiré.

    read -p "Sélectionnez le numéro de l'hôte à importer (exemple 1) ou 'all' pour tout importer, et vide pour annuler : " choix

    if [ -z "$choix" ]; then
        echo "Importation annulée."
        return 0
    fi

    declare -a hosts_selectionnes
    if [ "$choix" == "all" ]; then
        hosts_selectionnes=("${HOSTS[@]}")
    elif [[ "$choix" =~ ^[0-9]+$ ]] && [ "$choix" -ge 1 ] && [ "$choix" -le ${#HOSTS[@]} ]; then
        hosts_selectionnes+=("${HOSTS[$((choix-1))]}")
    else
        echo -e "$ERREUR Sélection invalide"
        return 1
    fi

    echo "" >> "$SSH_CONFIG_COFFRE"

    for host in "${hosts_selectionnes[@]}"; do
        echo "Importation de la configuration pour l'hôte : $host"

        awk -v nom_host="$host" '
            /^Host / { in_block = 0 }
            $2 == nom_host { in_block = 1; print; next }
            in_block { print }
        ' "$UTILISATEUR_SSH_CONFIG" | while IFS= read -r line; do
            if [[ "$line" =~ IdentityFile\ (.*) ]]; then
                chemin_original_cle_raw="${BASH_REMATCH[1]}"
                chemin_original_cle="${chemin_original_cle_raw/\~/$ORIGINAL_USER_HOME}"
                if [[ ! "$chemin_original_cle" =~ ^/ ]]; then
                    chemin_original_cle="$ORIGINAL_USER_HOME/$chemin_original_cle"
                fi

                cle_filename=$(basename "$chemin_original_cle")
                nouveau_chemin_cle="$SSH_COFFRE_DIR/$cle_filename"

                if [ -f "$chemin_original_cle" ]; then
                    echo "Copie de la clé privée : $chemin_original_cle vers $nouveau_chemin_cle"
                    cp "$chemin_original_cle" "$nouveau_chemin_cle" || { echo -e "$ERREUR Impossible de copier la clé privée"; continue; }
                    chmod 600 "$nouveau_chemin_cle"
                else
                    echo -e "\e[33mAvertissement: Clé privée '$chemin_original_cle' non trouvée\e[0m"
                fi

                if [ -f "${chemin_original_cle}.pub" ]; then
                    echo "Copie de la clé publique : ${chemin_original_cle}.pub vers ${nouveau_chemin_cle}.pub"
                    cp "${chemin_original_cle}.pub" "${nouveau_chemin_cle}.pub" || { echo -e "$ERREUR Impossible de copier la clé publique"; continue; }
                    chmod 644 "${nouveau_chemin_cle}.pub"
                else
                    echo -e "\e[33mAvertissement: Clé publique '${chemin_original_cle}.pub' non trouvée.\e[0m"
                fi

                echo "    IdentityFile $nouveau_chemin_cle" >> "$SSH_CONFIG_COFFRE"
            else
                echo "$line" >> "$SSH_CONFIG_COFFRE"
            fi
        done
        echo "Configuration de l'hôte '$host' importée dans '$SSH_CONFIG_COFFRE'"
        echo "" >> "$SSH_CONFIG_COFFRE"
    done

    echo -e "\e[33mACTION REQUISE: Vous devez maintenant éditer manuellement votre $UTILISATEUR_SSH_CONFIG"
    echo -e "et modifier la ligne IdentityFile pour l'hôte afin de pointer vers la clé dans le coffre ($SSH_COFFRE_DIR) "
    echo -e "ou utiliser l'alias 'evsh' si disponible\e[0m"
    echo ""
    echo "Importation SSH terminée"
    echo "Vérifiez $SSH_CONFIG_COFFRE pour les configurations importées"
}