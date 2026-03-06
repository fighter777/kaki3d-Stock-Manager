# -*- coding: utf-8 -*-
import psycopg2
import streamlit as st

def get_connection():
    connexion = None  # On initialise pour eviter le plantage au return
    try:
        connexion = psycopg2.connect(
        host=st.secrets["database"]["host"],
        dbname=st.secrets["database"]["dbname"],
        user=st.secrets["database"]["user"],
        password=st.secrets["database"]["password"],
        port=st.secrets["database"]["port"]
    )
    except psycopg2.Error as e:
        print(f"Erreur lors de la connexion : {e}")
    
    return connexion

if __name__ == "__main__":
    test_conn = get_connection()
    if test_conn:
        print("Connexion réussie, bravo Quentin !")
        test_conn.close()