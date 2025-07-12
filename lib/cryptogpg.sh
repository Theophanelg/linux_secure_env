#!/bin/bash

: "${MOUNT:=/mnt/secure_env}"
cle_gpg_dir="$MOUNT/gpg_cles"

gpg_create_cles() {
    echo "--- Création d'une nouvelle paire de clés GPG ---"
    read -p "Nom d'utilisateur : " pseudo
    read -p "Adresse email : " email
    read -p "Commentaire (Non-obligatoire) : " commentaire

    if ! command -v gpg &> /dev/null; then
        echo -e "$ERREUR GnuPG pas installé. Lancement de l'installation"
        sudo apt install gnupg
    fi

    GPG_TEMPORAIRE_FILE=$(mktemp)
    cat <<EOF > "$GPG_TEMPORAIRE_FILE"
        %no-protection
        Key-Type: RSA
        Key-Length: 4096
        Subkey-Type: RSA
        Subkey-Length: 4096
        Name-Real: $pseudo
        Name-Comment: $commentaire
        Name-Email: $email
        Expire-Date: 0
        %commit
EOF

    mkdir -p "$cle_gpg_dir" || {
        echo -e "$ERREUR Impossible de créer un répertoire de clés GPG dans le coffre : $cle_gpg_dir"
        exit 1
    }

    echo "On génère les clés GPG.."
    gpg --batch --full-generate-key --homedir "$cle_gpg_dir" "$GPG_TEMPORAIRE_FILE" 2>/dev/null || {
        echo -e "$ERREUR Echec de la generation de la paire de clés gpg"
        rm -f "$GPG_TEMPORAIRE_FILE"
        exit 1
    }

    echo "Clés GPG générée avec succès, stockée dans l'environnement sécurisé : $cle_gpg_dir"
    rm -f "$GPG_TEMPORAIRE_FILE"
}

gpg_exportation_cle_public() {
    echo "--- Export de la clé publique dans l'environnement sécurisé ---"
    read -p "Id ou email de la clé publique à exporter : " key_id

    if ! mountpoint -q "$MOUNT"; then
        echo -e "$ERREUR l'environnement sécurisé n'est pas monté $MOUNT"
        exit 1
    fi

    mkdir -p "$cle_gpg_dir" || {
        echo -e "$ERREUR Impossible de créer le répertoire $cle_gpg_dir"
        exit 1
    }

    gpg --output "$cle_gpg_dir/${key_id}_public.asc" --armor --export "$key_id" || {
        echo -e "$ERREUR Echec de l'export de la clé publique pour $key_id"
        exit 1
    }

    echo "Clé publique de $key_id exporté vers $cle_gpg_dir/${key_id}_public.asc"
}

gpg_exportation_cle_privee(){
    echo "-- Export de la clé privée GPG ---"
    read -p "Id ou email de la clé privée à exporter : " key_id

    if ! mountpoint -q "$MOUNT"; then
        echo -e "$ERREUR l'environnement sécurisé n'est pas monté $MOUNT"
        exit 1
    fi

    mkdir -p "$cle_gpg_dir" || {
        echo -e "$ERREUR Impossible de créer le répertoire $cle_gpg_dir"
        exit 1
    }

    gpg --output "$cle_gpg_dir/${key_id}_private.asc" --armor --export-secret-keys "$key_id" || {
        echo -e "$ERREUR Echec de l'export de la clé privée pour $key_id"
        exit 1
    }

    echo "Clé privée de $key_id exporté vers $cle_gpg_dir/${key_id}_private.asc"
}

gpg_importation_depuis_coffre() {
    echo "--- Import des clés GPG depuis le coffre vers le trousseau local ---"
    if ! mountpoint -q "$MOUNT"; then
        echo -e "$ERREUR l'environnement sécurisé n'est pas monté $MOUNT"
        exit 1
    fi

    if [ ! -d "$cle_gpg_dir" ] || [ ! -f "$cle_gpg_dir/pubring.kbx" ]; then
        echo "Aucun trousseau GPG trouvé dans le coffre : $cle_gpg_dir"
        exit 0
    fi

    KEY_IDS_IN_VAULT=$(sudo gpg --homedir "$cle_gpg_dir" --list-keys --with-colons | awk -F: '/^(pub|sec):/ { print $5 }')
    SECRET_KEY_IDS_IN_VAULT=$(sudo gpg --homedir "$cle_gpg_dir" --list-secret-keys --with-colons | awk -F: '/^sec:/ { print $5 }')


    if [ -z "$KEY_IDS_IN_VAULT" ] && [ -z "$SECRET_KEY_IDS_IN_VAULT" ]; then
        echo "Aucune clé GPG trouvée dans le trousseau du coffre à importer."
        exit 0
    fi

    for key_id in $KEY_IDS_IN_VAULT; do
        TEMP_PUB_KEY_FILE=$(mktemp --tmpdir="$MOUNT" imported_gpg_pub.XXXXXXXX.asc)

        echo "Tentative d'exportation de la clé publique $key_id depuis le coffre."
        if sudo gpg --homedir "$cle_gpg_dir" --output "$TEMP_PUB_KEY_FILE" --armor --export "$key_id"; then
            echo "Importation de la clé publique : $key_id"
            sudo gpg --import "$TEMP_PUB_KEY_FILE" || {
                echo -e "$ERREUR Échec de l'importation de la clé publique $key_id vers le trousseau local."
            }
        else
            echo -e "$ERREUR Échec de l'exportation de la clé publique $key_id depuis le coffre."
        fi
        rm "$TEMP_PUB_KEY_FILE" 2>/dev/null || true
    done

    for key_id in $SECRET_KEY_IDS_IN_VAULT; do
        TEMP_PRIV_KEY_FILE=$(mktemp --tmpdir="$MOUNT" imported_gpg_priv.XXXXXXXX.asc)

        echo "Tentative d'exportation de la clé privée (secrète) $key_id depuis le coffre."
        if sudo gpg --homedir "$cle_gpg_dir" --output "$TEMP_PRIV_KEY_FILE" --armor --export-secret-keys "$key_id"; then
            echo "Importation de la clé privée (secrète) : $key_id"
            sudo gpg --import "$TEMP_PRIV_KEY_FILE" || {
                echo -e "$ERREUR Échec de l'importation de la clé privée (secrète) $key_id vers le trousseau local."
            }
        else
            echo "Aucune clé privée (secrète) exportable pour $key_id depuis le coffre ou erreur d'export."
        fi
        rm "$TEMP_PRIV_KEY_FILE" 2>/dev/null || true
    done

    echo "Importation des clés GPG terminée."
}

gpg_exportation_vers_coffre() {
    echo "--- Export des clés GPG vers le coffre ---"
    if ! mountpoint -q "$MOUNT"; then
        echo -e "$ERREUR L'environnement sécurisé n'est pas monté $MOUNT"
        exit 1
    fi

    mkdir -p "$cle_gpg_dir" || {
        echo -e "$ERREUR Impossible de créer le répertoire $cle_gpg_dir"
        exit 1
    }
    echo "Liste des clés gpg : "
    gpg --list-key --fingerprint
    echo

    read -p "Id ou email de la clé (publique ou privée) à exporter vers le coffre : " key_to_export
    for key_id in "$key_to_export"; do
        echo "Export de la clé publique $key_id"
        gpg --output "$cle_gpg_dir/${key_id}_public.asc" --armor --export "$key_id" || {
            echo -e "$ERREUR Echec de l'export de la clé publique pour $key_id"
            exit 1
        }

        read -p "Voulez vous également exporter la clé privée de $key_id vers le coffre ? (y/n) " confirm_private_export
        if [[ "$confirm_private_export" =~ ^[yY]$ ]]; then
            echo "Exportation de la clé privée $key_id"
            gpg --output "$cle_gpg_dir/${key_id}_private.asc" --armor --export-secret-keys "$key_id" || {
                echo -e "$ERREUR Echec de l'exportation de la clé privée pour $key_id"
                exit 1
            }
        fi
    done
    echo "Export des clés GPG dans le coffre terminé"
}