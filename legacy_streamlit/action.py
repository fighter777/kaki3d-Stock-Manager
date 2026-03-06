# -*- coding: utf-8 -*-
import psycopg2
from database import get_connection
from psycopg2.extras import RealDictCursor

# Whitelist de sécurité pour get_or_create_id
TABLES_AUTORISEES = {
    "marques": "nom_marques",
    "materials": "type_materials"
}

def add_spool(nfc_id, color_name, initial_weight, empty_weight, diametre, 
              temp_imp, temp_table, debit, pressure_adv, vit_max, vit_imp,
              id_marques, id_materials):
    connexion = get_connection()
    nfc_id = nfc_id if nfc_id else ""
    if connexion:
        try:
            with connexion:
                with connexion.cursor() as curs:
                    requete = """
                    INSERT INTO public.spools (
                        nfc_id, color_name, initial_weight, empty_spool_weight,
                        diametre, temperature_imp, temperature_table, debit,
                        pressure_advance, vit_volum_max, vit_imp, id_marques, id_materials
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s);
                    """
                    params = (
                        nfc_id, color_name, initial_weight, empty_weight,
                        diametre, temp_imp, temp_table, debit,
                        pressure_adv, vit_max, vit_imp, id_marques, id_materials
                    )
                    curs.execute(requete, params)
            return True
        except Exception as e:
            print(f"Erreur SQL lors de l'ajout : {e}")
            return False
        finally:
            connexion.close()
    return False

def get_aggregated_inventory():
    connexion = get_connection()
    inventory = []
    if connexion:
        try:
            with connexion.cursor(cursor_factory=RealDictCursor) as curs:
                requete = """
                SELECT 
                    m.nom_marques, 
                    mat.type_materials,
                    s.color_name,
                    SUM(s.initial_weight) AS total_initial,
                    (SUM(s.initial_weight) - COALESCE(SUM(u.weight_used), 0)) AS total_restant
                FROM public.spools s
                JOIN public.marques m ON s.id_marques = m.id_marques
                JOIN public.materials mat ON s.id_materials = mat.id_materials
                LEFT JOIN public.usage_logs u ON s.id_spools = u.id_spools
                GROUP BY m.nom_marques, mat.type_materials, s.color_name
                ORDER BY m.nom_marques;
                """
                curs.execute(requete)
                inventory = curs.fetchall()
        except Exception as e:
            print(f"Erreur agrégation : {e}")
        finally:
            connexion.close()
    return inventory

def usage_log(weight_used, date_print, id_spools, project_name):
    connexion = get_connection()
    if connexion:
        try:
            with connexion:
                with connexion.cursor() as curs:
                    requete = """
                    INSERT INTO public.usage_logs (weight_used, print_date, id_spools, project_name)
                    VALUES (%s, %s, %s, %s);
                    """
                    curs.execute(requete, (weight_used, date_print, id_spools, project_name))
            return True
        except Exception as e:
            print(f"Erreur lors de l'ajout de consommation : {e}")
            return False
        finally:
            connexion.close()
    return False

def get_inventory():
    connexion = get_connection()
    inventory = []
    if connexion:
        try:
            with connexion.cursor(cursor_factory=RealDictCursor) as curs:
                requete = """
                SELECT 
                    s.*, 
                    m.nom_marques, 
                    mat.type_materials,
                    (s.initial_weight - COALESCE(SUM(u.weight_used), 0)) AS poids_restant
                FROM public.spools s
                JOIN public.marques m ON s.id_marques = m.id_marques
                JOIN public.materials mat ON s.id_materials = mat.id_materials
                LEFT JOIN public.usage_logs u ON s.id_spools = u.id_spools
                GROUP BY s.id_spools, m.id_marques, m.nom_marques, mat.id_materials, mat.type_materials
                ORDER BY s.id_spools DESC;
                """
                curs.execute(requete)
                inventory = curs.fetchall()
        except Exception as e:
            print(f"Erreur : {e}")
        finally:
            connexion.close()
    return inventory

def get_all_brands():
    connexion = get_connection()
    if connexion:
        try:
            with connexion.cursor(cursor_factory=RealDictCursor) as curs:
                curs.execute("SELECT id_marques, nom_marques FROM public.marques ORDER BY nom_marques;")
                return curs.fetchall()
        finally:
            connexion.close()
    return []

def get_all_materials():
    connexion = get_connection()
    if connexion:
        try:
            with connexion.cursor(cursor_factory=RealDictCursor) as curs:
                curs.execute("SELECT id_materials, type_materials FROM public.materials ORDER BY type_materials;")
                return curs.fetchall()
        finally:
            connexion.close()
    return []

def get_or_create_id(table, column, value):
    """
    Vérifie si une valeur existe dans une table.
    Si oui, renvoie l'ID. Sinon, l'insère et renvoie le nouvel ID.
    """
    if not value:
        return None
    # Sécurité : on vérifie que la table est autorisée
    if table not in TABLES_AUTORISEES:
        print(f"Table '{table}' non autorisée !")
        return None
    connexion = get_connection()
    if connexion:
        try:
            with connexion:
                with connexion.cursor() as curs:
                    curs.execute(f"SELECT id_{table} FROM {table} WHERE {column} ILIKE %s", (value.strip(),))
                    res = curs.fetchone()
                    if res:
                        return res[0]
                    curs.execute(f"INSERT INTO {table} ({column}) VALUES (%s) RETURNING id_{table}", (value.strip(),))
                    return curs.fetchone()[0]
        finally:
            connexion.close()
    return None

def update_spool(id_spools, nfc_id, id_materials, id_marques, color_name, initial_weight,
                 empty_spool_weight, diametre, temperature_imp, temperature_table,
                 debit, pressure_advance, vit_volum_max, vit_imp=0):
    connexion = get_connection()
    if connexion:
        try:
            with connexion:
                with connexion.cursor() as curs:
                    requete = """
                    UPDATE public.spools SET
                        nfc_id = %s, id_materials = %s, id_marques = %s, color_name = %s,
                        initial_weight = %s, empty_spool_weight = %s, diametre = %s,
                        temperature_imp = %s, temperature_table = %s, debit = %s,
                        pressure_advance = %s, vit_volum_max = %s, vit_imp = %s
                    WHERE id_spools = %s;
                    """
                    curs.execute(requete, (
                        nfc_id, id_materials, id_marques, color_name, initial_weight,
                        empty_spool_weight, diametre, temperature_imp, temperature_table,
                        debit, pressure_advance, vit_volum_max, vit_imp, id_spools
                    ))
            return True
        except Exception as e:
            print(f"Erreur Update : {e}")
            return False
        finally:
            connexion.close()
    return False

def get_spool_by_nfc(nfc_uid: str):
    """
    Recherche une bobine par son UID NFC.
    Retourne un dict avec toutes les infos + poids_restant, ou None.
    """
    connexion = get_connection()
    if not connexion:
        return None
    try:
        with connexion.cursor(cursor_factory=RealDictCursor) as curs:
            requete = """
            SELECT
                s.*,
                m.nom_marques,
                mat.type_materials,
                (s.initial_weight - COALESCE(SUM(u.weight_used), 0)) AS poids_restant
            FROM public.spools s
            JOIN public.marques m ON s.id_marques = m.id_marques
            JOIN public.materials mat ON s.id_materials = mat.id_materials
            LEFT JOIN public.usage_logs u ON s.id_spools = u.id_spools
            WHERE s.nfc_id ILIKE %s
            GROUP BY s.id_spools, m.id_marques, m.nom_marques, mat.id_materials, mat.type_materials
            LIMIT 1;
            """
            curs.execute(requete, (nfc_uid.strip(),))
            return curs.fetchone()
    except Exception as e:
        print(f"Erreur get_spool_by_nfc : {e}")
        return None
    finally:
        connexion.close()

def get_stats_by_month():
    connexion = get_connection()
    if connexion:
        try:
            with connexion.cursor(cursor_factory=RealDictCursor) as curs:
                curs.execute("""
                SELECT 
                    DATE_TRUNC('month', print_date) AS mois,
                    SUM(weight_used) AS total_consomme
                FROM public.usage_logs
                GROUP BY mois
                ORDER BY mois;
                """)
                return curs.fetchall()
        finally:
            connexion.close()
    return []

def get_stats_by_project():
    connexion = get_connection()
    if connexion:
        try:
            with connexion.cursor(cursor_factory=RealDictCursor) as curs:
                curs.execute("""
                SELECT
                    project_name,
                    SUM(weight_used) AS total_consomme
                FROM public.usage_logs
                GROUP BY project_name
                ORDER BY total_consomme DESC
                LIMIT 6;
                """)
                return curs.fetchall()
        finally:
            connexion.close()
    return []

def get_stats_by_material():
    connexion = get_connection()
    if connexion:
        try:
            with connexion.cursor(cursor_factory=RealDictCursor) as curs:
                curs.execute("""
                SELECT 
                    mat.type_materials,
                    SUM(s.initial_weight) AS poids_total
                FROM public.spools s
                JOIN public.materials mat ON s.id_materials = mat.id_materials
                GROUP BY mat.type_materials
                ORDER BY poids_total DESC;
                """)
                return curs.fetchall()
        finally:
            connexion.close()
    return []
