

CREATE TABLE public.materials (
                id_materials INTEGER NOT NULL GENERATED always AS IDENTITY PRIMARY KEY,
                type_materials VARCHAR(50) NOT NULL,
                density numeric (4,2)
                
);


CREATE TABLE public.marques (
                id_marques INTEGER NOT NULL GENERATED always AS IDENTITY PRIMARY KEY,
                nom_marques VARCHAR(100) NOT NULL
);


CREATE TABLE public.spools (
                id_spools INTEGER NOT null GENERATED always AS IDENTITY PRIMARY KEY,
                nfc_id VARCHAR(255),
                id_materials INTEGER NOT null references public.materials(id_materials),
                id_marques INTEGER NOT null references public.marques(id_marques),
                color_name VARCHAR(100),
                initial_weight numeric(5,1) DEFAULT 1000,
                empty_spool_weight INTEGER,
                diametre numeric (4,2) NOT null,
                temperature_imp numeric(4,1) DEFAULT 0,
                temperature_table numeric(4,1) DEFAULT 0,
                debit numeric(4,1) DEFAULT 0,
                pressure_advance numeric(4,3) DEFAULT 0,
                vit_volum_max integer DEFAULT 10,
                vit_imp numeric (4,1) default 60
);


CREATE TABLE public.usage_logs (
                id_usage_logs INTEGER NOT null GENERATED always AS IDENTITY PRIMARY KEY,
                weight_used numeric (5,1) DEFAULT 0.0 NOT NULL,
                print_date DATE,
                id_spools INTEGER NOT null references public.spools(id_spools),
                project_name VARCHAR(255)
                
);
COMMENT ON TABLE public.usage_logs IS 'historique de consomation';


