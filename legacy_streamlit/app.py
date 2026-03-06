# -*- coding: utf-8 -*-
import streamlit as st
import pandas as pd
from action import get_inventory, add_spool, get_or_create_id, update_spool, usage_log, get_aggregated_inventory, get_all_materials, get_spool_by_nfc, get_stats_by_material, get_stats_by_project, get_stats_by_month
import time 
import datetime
import base64
from pathlib import Path
from config_custom import pseudo
import plotly.express as px

# Configuration de la page
st.set_page_config(page_title="Mon Stock de Filament - Kaki3D", layout="wide")

BASE_DIR = Path(__file__).resolve().parent

def get_base64(path):
    with open(path, "rb") as image_file:
        return base64.b64encode(image_file.read()).decode()

try:
    bin_str = get_base64(BASE_DIR / "asset" / "new_logo_kaki3d.png")
    logo_html = f'data:image/png;base64,{bin_str}'
except Exception:
    logo_html = ""

st.markdown(
    f"""
    <div style="background-color: #2e3440; padding: 20px; border-radius: 10px; border-left: 5px solid #4CAF50; margin-top: -60px;">
        <div style="display: flex; align-items: center; justify-content: center; gap: 20px;">
            <img src="{logo_html}" style="width: 200px;">
            <div style="flex-grow: 1;">
                <h1 style="color: white; margin-left: -40px; text-align: center;">
                    {pseudo} <span style="font-weight: 100;">| Stock Manager</span>
                </h1>
                <p style="color: #d8dee9; text-align: center; margin-left: -40px;">
                    Suivi des consommations et inventaire des bobines
                </p>
            </div>
        </div>
    </div>
    <br>
    """,
    unsafe_allow_html=True
)

# Initialisation session
if "nfc_uid" not in st.session_state:
    st.session_state.nfc_uid = None
if "nfc_ajout" not in st.session_state:
    st.session_state.nfc_ajout = None

# Intercepte le retour de nfc.html
if "nfc_uid" in st.query_params:
    st.session_state.nfc_uid = st.query_params["nfc_uid"].upper()
    st.query_params.clear()
    st.query_params["page"] = "nfc"  # ← force la page NFC
    st.rerun()

# Gestion de la redirection NFC
if st.session_state.get("redirect_to"):
    target = st.session_state.redirect_to
    st.session_state.redirect_to = None
    st.query_params["page"] = target
    st.rerun()

# Définition des pages
pages = [
    ":material/inventory_2: État du stock",
    ":material/add_circle: Ajouter une bobine",
    ":material/analytics: Statistiques & Analyse",
    ":material/tune: Modifier une bobine",
    ":material/monitor_weight: Consommation",
    ":material/nfc: Scanner NFC"
]

# Index par défaut selon la redirection
default = 0
if st.query_params.get("page") == "ajout":
    default = 1
    st.query_params.clear()
elif st.query_params.get("page") == "nfc":
    default = 5
    st.query_params.clear()

st.sidebar.title("Menu")
menu = st.sidebar.radio("Navigation", pages, index=default)

# --- 1. ÉTAT DU STOCK ---
if menu == ":material/inventory_2: État du stock":
    st.title(":material/inventory_2: État de l'inventaire")
    data = get_inventory()
    data_global = get_aggregated_inventory()

    if data_global:
        cols = st.columns(4)
        for i, b in enumerate(data_global):
            with cols[i % 4]:
                total_i = float(b['total_initial'])
                total_r = float(b['total_restant'])
                ratio = max(0.0, min(1.0, total_r / total_i)) if total_i > 0 else 0
                st.metric(f"{b['nom_marques']} - {b['color_name']}", f"{int(total_r)}g")
                st.progress(ratio)
                st.caption(f"Type: {b['type_materials']}")
    else:
        st.info("Aucune donnée à agréger.")
    st.divider()
    if data:
        df = pd.DataFrame(data)
        st.dataframe(df, use_container_width=True)

# --- 2. AJOUT D'UNE BOBINE ---
elif menu == ":material/add_circle: Ajouter une bobine":
    st.title(":material/add_circle: Enregistrer un nouveau filament")

    liste_matieres_brute = get_all_materials() 
    dict_matieres = {m['type_materials']: m['id_materials'] for m in liste_matieres_brute}
    noms_matieres = list(dict_matieres.keys())
    c1,c2,c3 = st.columns(3)
    with c1:
        options_avec_ajout = noms_matieres + ["Ajouter une nouvelle matière..."]
        choix_matiere = st.selectbox("Choisir la matière", options=options_avec_ajout)

        if choix_matiere == "Ajouter une nouvelle matière...":
            nouvelle_matiere = st.text_input("Nom de la nouvelle matière (ex: Carbon Fiber)")
            if nouvelle_matiere:
                st.session_state.id_mat = get_or_create_id("materials", "type_materials", nouvelle_matiere)
                st.session_state.nom_mat_temp = (nouvelle_matiere)
        elif choix_matiere:
            st.session_state.id_mat = dict_matieres[choix_matiere]
    if "nfc_ajout" not in st.session_state:
        st.session_state.nfc_ajout = None

    with st.form("form_spool", clear_on_submit=True):
        col1, col2 = st.columns(2)
        with col1:
            brand_name = st.text_input("Marque (ex: Prusament, Esun)")
            color = st.text_input("Nom de la couleur")
            nfc = st.text_input("ID Tag NFC", value=st.session_state.get("nfc_ajout", ""))
        with col2:
            w_init = st.number_input("Poids initial (g)", value=1000.0, step=1.0)
            w_empty = st.number_input("Poids bobine vide (g)", value=200.0, step=1.0)
            diam = st.number_input("Diamètre (mm)", value=1.75, step=0.01)

        st.divider()
        st.subheader("Paramètres techniques (Slicer)")
        c1, c2, c3 = st.columns(3)
        with c1:
            t_imp = st.number_input("Temp. Buse (°C)", value=200.0)
            t_tab = st.number_input("Temp. Plateau (°C)", value=50.0)
        with c2:
            vit_imp = st.number_input("Vit. d'impression(mm/s)", value=60)
            deb = st.number_input("Débit (%)", value=100.0)
        with c3:
            pa = st.number_input("Pressure Advance", value=0.000, step=0.001, format="%.3f")
            vit = st.number_input("Vit. Vol. Max", value=15)
        
        if st.form_submit_button("🚀 Enregistrer en base"):
            id_mat = st.session_state.get("id_mat")
            st.write(f"DEBUG id_mat = {id_mat}")  # ← ajoute ça temporairement
            if brand_name and color and id_mat:
                id_m = get_or_create_id("marques", "nom_marques", brand_name)
                if add_spool(
                    nfc_id=nfc, color_name=color, initial_weight=w_init,
                    empty_weight=w_empty, diametre=diam, temp_imp=t_imp,
                    temp_table=t_tab, debit=deb, pressure_adv=pa,
                    vit_max=vit, id_marques=id_m, id_materials=id_mat, vit_imp=vit_imp
                ):
                    st.session_state.nfc_ajout = None
                    st.success(f"✅ Bobine {brand_name} {color} ajoutée !")
                else:
                    st.error("Erreur technique lors de l'insertion.")
            else:
                st.warning("Marque, Matière et Couleur sont obligatoires !")

# --- 3. STATISTIQUES ---
elif menu == ":material/analytics: Statistiques & Analyse":
    st.title(":material/analytics: Statistiques")
    c1, c2 = st.columns(2)
    data_material = get_stats_by_material()
    data_month = get_stats_by_month()
    data_project = get_stats_by_project()
    df_month = pd.DataFrame(data_month)
    df_material = pd.DataFrame(data_material)
    df_project = pd.DataFrame(data_project)
    with c1 : 
        if not df_material.empty:
            fig = px.bar(df_material,
                    x="type_materials",
                    y= "poids_total", 
                    color="type_materials",
                    title="Stock par matières", 
                    labels= {"type_materials":"Matière", "poids_total":"Poid en stock"}, 
                    text_auto=True
                    )
            st.plotly_chart(fig)
    with c2 :
        if not df_project.empty:
            fig_project = px.bar(df_project,
                             x="project_name",
                             y= "total_consomme",
                             title="consommation par projet",
                             color_discrete_sequence=["#00FFC8"],
                             labels={"project_name":"Nom du projet", "total_consomme":"Consomation"},
                             text_auto=True)
            st.plotly_chart(fig_project)
    if not df_month.empty:
        fig_month = px.line(df_month, 
                        x="mois", y="total_consomme",
                        title="Consomation dans le temps",
                        color_discrete_sequence=["#00FFC8"],
                        labels={"total_consomme":"Consomation"})
        fig_month.update_xaxes(
        dtick="M1",                    # ← un tick par mois
        tickformat="%b %Y")            # ← format "Jan 2026"
        st.plotly_chart(fig_month)

# --- 4. MODIFIER UNE BOBINE ---
elif menu == ":material/tune: Modifier une bobine":
    if st.session_state.get('update_success'):
        st.toast("Modifications enregistrées !", icon="✅")
    st.session_state.update_success = False
    st.title("Modifier une bobine")
    data = get_inventory()
    c1, c2, _ = st.columns(3)
    if data:
        with c1:
            choix = st.selectbox(
                label="Sélectionner la bobine à modifier", options=data,
                format_func=lambda b: f"{b['nom_marques']} - {b['color_name']} ({b['poids_restant']}g)")
        with st.form("edition"):
            nouvelle_couleur = st.text_input("Couleur", value=choix['color_name'])
            nouvelle_marque = st.text_input("Marque", value=choix['nom_marques'])
            nouveau_nfc_id = st.text_input("NFC ID", value=choix['nfc_id'])
            nouveau_material = st.text_input("Matiere", value=choix['type_materials'])
            st.divider()
            st.subheader("Paramètres techniques (Slicer)")
            c1, c2, c3 = st.columns(3)
        with c1:
            nouvelle_temp = st.number_input("Temperature buse (°C)", value=float(choix['temperature_imp']))
            nouvelle_temp_tab = st.number_input("Temperature plateau (°C)", value=float(choix['temperature_table']))
        with c2:
            nouv_vit_imp = st.number_input("Vitesse impression (mm/s)", value=float(choix['vit_imp']))
            nouveau_debit = st.number_input("Débit (%)", value=float(choix['debit']))
        with c3:
            nouvelle_PA = st.number_input("Pressure advance ", value=float(choix['pressure_advance']))
            nouvelle_Vmax = st.number_input("Vitesse volumetrique (mm³/s)", value=float(choix['vit_volum_max']))
        with c1:
            submit = st.form_submit_button("Enregistrer les modifications")
        if submit:
            id_m = get_or_create_id("marques", "nom_marques", nouvelle_marque)
            id_mat = get_or_create_id("materials", "type_materials", nouveau_material)
            succes = update_spool(
                id_spools=choix['id_spools'], nfc_id=nouveau_nfc_id,
                id_materials=id_mat, id_marques=id_m, color_name=nouvelle_couleur,
                initial_weight=choix['initial_weight'], empty_spool_weight=choix['empty_spool_weight'],
                diametre=choix['diametre'], temperature_imp=nouvelle_temp,
                temperature_table=nouvelle_temp_tab, vit_imp=nouv_vit_imp,
                debit=nouveau_debit, pressure_advance=nouvelle_PA, vit_volum_max=nouvelle_Vmax
            )
            if succes:
                st.session_state.update_success = True
                st.rerun()
            else:
                st.error("Erreur lors de la mise à jour en base.")
    else:
        st.warning("⚠️ Aucune donnée trouvée dans la base.")

# --- 5. CONSOMMATION ---
elif menu == ":material/monitor_weight: Consommation":
    if st.session_state.get('conso_success'):
        st.toast("Consommation enregistrées !", icon="✅")
    st.session_state.conso_success = False
    st.title(":material/monitor_weight: Consommation filament")
    data = get_inventory()
    c1, c2, c3 = st.columns(3)
    if data:
        with c1:
            choix = st.selectbox(
                label="Sélectionner la bobine utilisée", options=data,
                format_func=lambda b: f"{b['nom_marques']} - {b['color_name']} ({b['poids_restant']}g)")
        with c1:
            with st.form("Ajout"):
                nom_projet = st.text_input("Nom du projet imprimé")
                consommation = st.number_input("Poids consommé (g)", value=100.0, step=1.0, max_value=float(choix['poids_restant']))
                date_print = st.date_input("Date de l'impression", value=datetime.date.today())
                submit = st.form_submit_button("Enregistrer la consommation")
            if submit:
                succes = usage_log(
                    weight_used=consommation, date_print=date_print,
                    id_spools=choix['id_spools'], project_name=nom_projet
                )
                if succes:
                    st.session_state.conso_success = True
                    st.rerun()
                else:
                    st.error("Erreur lors de la mise à jour en base.")
    else:
        st.warning("⚠️ Aucune donnée trouvée dans la base.")

# --- 6. SCANNER NFC ---
elif menu == ":material/nfc: Scanner NFC":
    st.title(":material/nfc: Scanner une bobine NFC")

    # Initialise la session
    if "nfc_uid" not in st.session_state:
        st.session_state.nfc_uid = None

    # Récupère l'UID si on revient de la page NFC statique
    params = st.query_params
    if "nfc_uid" in params:
        st.session_state.nfc_uid = params["nfc_uid"].upper()
        st.query_params.clear()
        st.rerun()

    # Bouton qui ouvre la page NFC statique (hors iframe = NFC fonctionne ✅)
    app_url = "https://kaki3d-stock-manager.streamlit.app"
    
    if not st.session_state.nfc_uid:
        st.subheader("Étape 1 – Scanner le tag")
        st.markdown("> ⚠️ **Android + Chrome uniquement**")
        
        st.link_button(
            "📡 Scanner un tag NFC",
            url=f"https://kakicrypto.github.io/kaki3d-Stock-Manager/nfc.html?return={app_url}"
        )

        # Fallback saisie manuelle
        with st.expander("✏️ Saisie manuelle de l'UID (fallback desktop)"):
            uid_manuel = st.text_input("UID NFC", placeholder="ex: 04:AB:12:CD:EF:00:01")
            if st.button("Rechercher", key="btn_manuel"):
                st.session_state.nfc_uid = uid_manuel.strip().upper()
                st.rerun()

    # Affichage de la bobine si UID disponible
    if st.session_state.nfc_uid:
        uid = st.session_state.nfc_uid
        st.info(f"🔎 Recherche de la bobine avec l'UID : `{uid}`")

        spool = get_spool_by_nfc(uid)

        if spool is None:
            st.error(f"❌ Aucune bobine trouvée pour l'UID **{uid}**.")
            st.session_state.nfc_ajout = uid
            st.session_state.nfc_uid = None  # ← reset le scan
            st.session_state.redirect_to = "ajout"
            st.rerun()
            if st.button("🔄 Réinitialiser"):
                st.session_state.nfc_uid = None
                st.rerun()
        else:
            st.success("✅ Bobine trouvée !")
            st.subheader(f":material/inventory_2: {spool['nom_marques']} — {spool['color_name']}")

            col1, col2, col3 = st.columns(3)
            with col1:
                st.metric("Matière", spool['type_materials'])
                st.metric("Diamètre", f"{spool['diametre']} mm")
            with col2:
                st.metric("Poids restant", f"{int(spool['poids_restant'])} g")
                st.metric("Poids initial", f"{int(spool['initial_weight'])} g")
            with col3:
                st.metric("Temp. buse", f"{int(spool['temperature_imp'])} °C")
                st.metric("Temp. plateau", f"{int(spool['temperature_table'])} °C")

            ratio = max(0.0, min(1.0, float(spool['poids_restant']) / float(spool['initial_weight'])))
            st.progress(ratio, text=f"Remplissage : {ratio*100:.0f}%")

            with st.expander("⚙️ Paramètres Slicer"):
                c1, c2, c3 = st.columns(3)
                with c1: st.metric("Débit", f"{spool['debit']} %")
                with c2: st.metric("Pressure Advance", spool['pressure_advance'])
                with c3: st.metric("Vit. vol. max", f"{spool['vit_volum_max']} mm³/s")

            st.divider()
            st.subheader("Étape 2 – Enregistrer une consommation")

            with st.form("form_nfc_conso"):
                nom_projet = st.text_input("Nom du projet imprimé")
                consommation = st.number_input(
                    "Poids consommé (g)", value=10.0, step=1.0,
                    min_value=0.1, max_value=float(spool['poids_restant'])
                )
                date_print = st.date_input("Date d'impression", value=datetime.date.today())
                submit_conso = st.form_submit_button("💾 Enregistrer la consommation")

            if submit_conso:
                succes = usage_log(
                    weight_used=consommation, date_print=date_print,
                    id_spools=spool['id_spools'], project_name=nom_projet
                )
                if succes:
                    st.success(f"✅ {consommation}g enregistrés pour « {nom_projet} » !")
                    time.sleep(1.5)
                    st.session_state.nfc_uid = None
                    st.rerun()
                else:
                    st.error("Erreur lors de l'enregistrement en base.")

            if st.button("🔄 Scanner une autre bobine"):
                st.session_state.nfc_uid = None
                st.rerun()
