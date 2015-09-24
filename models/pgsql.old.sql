--
-- PostgreSQL database dump
--

-- Dumped from database version 9.4.4
-- Dumped by pg_dump version 9.4.4
-- Started on 2015-09-23 17:38:16 CST

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- TOC entry 211 (class 3079 OID 11861)
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- TOC entry 2300 (class 0 OID 0)
-- Dependencies: 211
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- TOC entry 574 (class 1247 OID 28275)
-- Name: dominio_email; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN dominio_email AS character varying(150)
	CONSTRAINT dominio_email_check CHECK (((VALUE)::text ~ '^[A-Za-z0-9](([_.-]?[a-zA-Z0-9]+)*)@([A-Za-z0-9]+)(([.-]?[a-zA-Z0-9]+)*).([A-Za-z]{2,})$'::text));


--
-- TOC entry 576 (class 1247 OID 28277)
-- Name: dominio_ip; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN dominio_ip AS character varying(15)
	CONSTRAINT dominio_ip_check CHECK ((((VALUE)::inet > '0.0.0.0'::inet) AND ((VALUE)::inet < '223.255.255.255'::inet)));


--
-- TOC entry 578 (class 1247 OID 28279)
-- Name: dominio_xml; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN dominio_xml AS text
	CONSTRAINT dominio_xml_check CHECK ((VALUE)::xml IS DOCUMENT);


--
-- TOC entry 224 (class 1255 OID 28281)
-- Name: adduser(text, text, text, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION adduser(text, text, text, bigint) RETURNS integer
    LANGUAGE plpgsql
    AS '
/**
 * Funcion que registra un usuario del sistema,
 * se activa por envio de mensajes de texto (sms)
 * 
 * Acceso: publico
 * Autor:  William Vides - wilx.sv@gmail.com
 * Fecha: 2012.04.11
 * Elemplo: SELECT adduser(''USER-1'', ''un nombre'', ''un apellido'', 79797373);
 *
*/
DECLARE
    v_username ALIAS FOR $1;
    v_nombre ALIAS FOR $2;
    v_apellido ALIAS FOR $3;
    v_telefono ALIAS FOR $4;
BEGIN
    INSERT INTO scd_usuario(
            username, "password", correousuario, detalleusuario, ultimavisitausuario, 
            ipusuario, salt, nombreusuario, apellidousuario, telefonousuario, 
            nacimientousuario, latusuario, lonusuario, direccionusuario, 
            sexousuario, registrousuario, estado_id, localidad_id)
    VALUES (v_username, ''n/a'', v_username||''@local.lo'', ''usuario registrado desde telefono'', now()::timestamp(0) without time zone, 
            ''127.0.0.1'', ''n/a'', v_nombre, v_apellido, v_telefono, 
            now()::date - 365*18, 13.704032, -89.188385, ''n/a'', 
            0, now()::timestamp(0) without time zone, 3, 1);
    RAISE INFO '' :: Usuario [%] registrado con exito :: '', v_username;
    RETURN 1;
END;
';


--
-- TOC entry 225 (class 1255 OID 28282)
-- Name: enviar_sms(bigint, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION enviar_sms(bigint, text) RETURNS integer
    LANGUAGE plpgsql
    AS '
/**
 * Funcion que registra un sms a enviar
 * 
 * Acceso: publico
 * Autor:  William Vides - wilx.sv@gmail.com
 * Fecha: 2012.05.02
 * Elemplo: 
 *
*/
DECLARE
    numero ALIAS FOR $1;
    mensaje ALIAS FOR $2;
    sms_hex text;
BEGIN
    --SELECT * INTO sms_hex FROM encode( mensaje, ''HEX'');
    --INSERT INTO outbox( destinationnumber, textdecoded, creatorid)
    --VALUES ( numero, mensaje, ''Gammu 1.28.0'');
    --RAISE INFO '' :: Salida de mensaje registrada con exito :: '';
    RETURN 1;
END;
';


--
-- TOC entry 226 (class 1255 OID 28283)
-- Name: filtra_sms_recivido(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION filtra_sms_recivido() RETURNS trigger
    LANGUAGE plpgsql
    AS '
/**
 * Funcion que filtra tuplas en base a una cadena de texto y a un prefijo,
 * si se encuentra el prefijo, el mensaje es enviado a la funcion con ese nombre,
 * el mensaje es recibido si lo permiten las reglas, si no es enviado a XXX
 * 
 * Acceso: publico
 * Autor:  William Vides - wilx.sv@gmail.com
 * Fecha: 2012.05.01
 *
*/
DECLARE
    v_item RECORD;
    v_id integer;
    v_parametro character varying(10);
BEGIN
    IF (TG_OP = ''INSERT'') THEN
        SELECT prefijo INTO v_parametro FROM prefijo(NEW.textdecoded);
        --Esta consulta se debe mejorar agregando en el WHERE el numero de telefono [aplicable a funciones que no sean registrame]
        SELECT * INTO v_item FROM scd_regla_sms 
                                  WHERE prefijoregla = v_parametro AND inicioregla <= now() AND finregla >= now();
        IF (v_item NOTNULL) THEN
            RAISE INFO '' :: Mensaje con prefijo valido :: '';
            IF (v_parametro = ''registrame'') THEN
                RAISE INFO '' :: Datos enviados a funcion registrame() :: '';
                v_id := registrame(NEW.sendernumber, NEW.textdecoded);
            END IF;
        ELSE
            RAISE INFO '' :: Operacion invalida, regla no tiene asociada una funcion :: '';
            --Registro de mensajes en tabla de sms_otros
            SELECT last_value INTO v_id FROM inbox_id_seq;
            INSERT INTO scd_otros_sms(mensajeotrosms, numerootrosms, inbox_id, registrotrosms)
            VALUES (NEW.textdecoded, NEW.sendernumber, v_id, NEW.receivingdatetime);
        END IF;
    END IF;
    RETURN NEW;
END;
';


--
-- TOC entry 227 (class 1255 OID 28284)
-- Name: get_id_usuario(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_id_usuario(bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS '
/**
 * Funcion que retorna la llave primaria del usuario asociado
 * al numero consultado, si no existe el usuario retorna el valor de 0
 * 
 * Acceso: publico
 * Autor:  William Vides - wilx.sv@gmail.com
 * Fecha: 2012.04.11
 * Elemplo: SELECT * FROM get_id_usuario(79797373);
 *
*/
DECLARE
    numero ALIAS FOR $1;
    v_item RECORD;
BEGIN
    SELECT * INTO v_item FROM "scd_usuario" WHERE ("telefonousuario" = numero);
    IF v_item.id IS NOT NULL  THEN
        RAISE INFO '' :: Usuario registrado [Telefono con registro asociado en el catalogo de usuarios] :: '';
        RETURN v_item.id;
     ELSE
        RAISE INFO '' :: Usuario no registrado [Telefono sin registro asociado en el catalogo de usuarios] :: '';
        RETURN 0;
     END IF;
END  
';


--
-- TOC entry 228 (class 1255 OID 28285)
-- Name: get_numero(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_numero(text) RETURNS bigint
    LANGUAGE plpgsql
    AS '
/**
 * Funcion que retorna un numero, si recibe un alfanumerico retorna 0
 * 
 * Acceso: publico
 * Autor:  William Vides - wilx.sv@gmail.com
 * Fecha: 2012.04.11
 * Elemplo: SELECT * FROM get_numero(''79797373'');
 *
*/
DECLARE
    numero ALIAS FOR $1;
    v_numero BIGINT;
BEGIN
    SELECT * INTO v_numero FROM CAST(numero AS bigint);
    RETURN v_numero;
    EXCEPTION
        WHEN invalid_text_representation THEN
            RETURN 0;
END;
';


--
-- TOC entry 229 (class 1255 OID 28286)
-- Name: guarda_estado(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION guarda_estado() RETURNS trigger
    LANGUAGE plpgsql
    AS '
/**
 * Funcion que se activa en la tabla scd_estado y evita la edicion
 * de una tupla si se trata de modificar el nombre o id de la tupla,
 * asi como tambien si se trata de eliminar.
 * 
 * Acceso: publico
 * Autor:  William Vides - wilx.sv@gmail.com
 * Fecha: 2012.04.11
 *
*/
BEGIN
     IF (TG_OP = ''UPDATE'') THEN
         IF (NEW.nombreestado <> OLD.nombreestado OR NEW.id <> OLD.id) THEN
             RAISE EXCEPTION '' :: Operacion invalida, nombreestado sin modificaciones :: '';
             RETURN OLD;
         END IF;
     END IF;
     IF (TG_OP = ''DELETE'') THEN
         RAISE EXCEPTION '' :: Operacion invalida, estado sin eliminarse :: '';
         RETURN NULL;
     END IF;
END;
';


--
-- TOC entry 230 (class 1255 OID 28287)
-- Name: nueva_regla(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION nueva_regla() RETURNS trigger
    LANGUAGE plpgsql
    AS '
/**
 * Funcion que habilita el registro de una regla, unicamente si existe
 * una funcion con el mismo nombre (prefijoregla = nombre-funcion).
 * 
 * Acceso: publico
 * Autor:  William Vides - wilx.sv@gmail.com
 * Fecha: 2012.04.11
 * 
*/
DECLARE
    v_item RECORD;
BEGIN
     IF (TG_OP = ''INSERT'') THEN
         SELECT * INTO v_item FROM pg_proc proc JOIN pg_language lang ON proc.prolang = lang.oid
                  WHERE proc.proname = NEW.prefijoregla;/*AND lang.lanname = ''plpgsql''*/
         IF (v_item NOTNULL) THEN
             RAISE INFO '' :: Operacion asociada a regla :: '';
             RETURN NEW;
         ELSE
             RAISE EXCEPTION '' :: Operacion invalida, regla no tiene asociada una funcion :: '';
             RETURN NULL;
         END IF;
     END IF;
END;
';


--
-- TOC entry 231 (class 1255 OID 28288)
-- Name: prefijo(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION prefijo(text) RETURNS text
    LANGUAGE plpgsql
    AS '
/**
 * Funcion que retorna la primer palabra en minusculas de una cadena enviada
 * 
 * Acceso: publico
 * Autor:  William Vides - wilx.sv@gmail.com
 * Fecha: 2012.04.11
 * Elemplo: SELECT * FROM prefijo('' palabra de ejemplo''); - Retorna ''palabra''
 *
*/
DECLARE
    mensaje ALIAS FOR $1;
    v_prefijo text;
    v_limite INTEGER;
BEGIN
    SELECT * INTO v_limite FROM position('' '' in trim(lower(mensaje)));
    RAISE INFO ''Limite %'', v_limite;
    SELECT * INTO v_prefijo FROM substring(trim(lower(mensaje)) from 1 for v_limite-1);
    RETURN v_prefijo;
END;
';


--
-- TOC entry 232 (class 1255 OID 28289)
-- Name: registrame(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION registrame(text, text) RETURNS integer
    LANGUAGE plpgsql
    AS '
/**
 * Funcion que registra a un usuario del sistema
 * se recibe un numero y una cadena, si el telefono existe no se registra,
 * si no, se evalua el formato con el nombre eviado y se generan los campos
 * adicionales al usuario
 * 
 * Acceso: publico
 * Autor:  William Vides - wilx.sv@gmail.com
 * Fecha: 2012.04.11
 * Elemplo: SELECT * FROM registrame(79797373, ''registrame juan ernesto-mira alvarez'');
 *
*/
DECLARE
    numero ALIAS FOR $1;
    mensaje ALIAS FOR $2;
    v_telefono BIGINT;
    v_limite INTEGER;
    v_mensaje TEXT;
    v_longitud INTEGER;
    v_item BIGINT;
    v_fecha INTEGER;
    v_nombre TEXT;
    v_apellido TEXT;
    v_usr TEXT;
    v_r RECORD;
BEGIN
    v_telefono := get_numero(numero);
    IF v_telefono > 0 THEN
        v_item := get_id_usuario(v_telefono);
        IF v_item = 0  THEN
            SELECT * INTO v_limite FROM position('' '' in trim(lower(mensaje)));
            SELECT * INTO v_longitud FROM char_length(trim(lower(mensaje)));
            SELECT * INTO v_mensaje FROM substring(trim(lower(mensaje)) from v_limite+1 for v_longitud);-- mensaje sin prefijo de registro
            SELECT * INTO v_limite FROM position(''-'' in v_mensaje);
            IF v_limite > 0 THEN
                SELECT * INTO v_nombre FROM substring(v_mensaje from 1 for v_limite-1);--asignacion de nombre
                SELECT * INTO v_apellido FROM substring(v_mensaje from v_limite+1 for v_longitud);--asignacion de apellido
                SELECT * INTO v_r FROM scd_usuario_id_seq;
                v_usr := ''usuario-''||v_r.last_value;
                v_limite := adduser(v_usr, v_nombre, v_apellido, v_telefono);
                RAISE INFO '' :: Usuario [%] registrado con exito :: '', v_r.last_value;
                v_limite := enviar_sms(v_telefono, ''Bienvenido, ya formas parte del sistema de comunicacion digital comunitaria'');
                RETURN v_r.last_value;
            ELSE
                RAISE NOTICE '' :: Usuario no registrado [formato incorrecto de nombre y apellido] :: '';
                v_limite := enviar_sms(v_telefono, ''Intenta de nuevo y envia correctamente el mensaje. El formato de registro es "registrame y tu nombre", ejemplo: "registrame Oscar Arnulfo-Romero Galdamez"'');
                RETURN 0;
            END IF;
        ELSE
           RAISE INFO '' :: No se registrara este telefono :: '';
           RETURN 0;
        END IF;
    ELSE
        RAISE INFO '' :: Usuario no registrado [formato incorrecto de telefono] :: '';
        RETURN 0;
    END IF;
END;
';


--
-- TOC entry 233 (class 1255 OID 28290)
-- Name: set_namespace(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION set_namespace() RETURNS trigger
    LANGUAGE plpgsql
    AS '
/**
 * Funcion que elimina las plecas invertidas en una cadena de texto,
 * usado para dar un formato especial a namespace de symfony 2
 * 
 * Acceso: publico
 * Autor:  William Vides - wilx.sv@gmail.com
 * Fecha: 2012.04.11
 * 
*/
BEGIN
     NEW.namespacetitulo = REPLACE(NEW.namespacetitulo, E''\\\\'', '''');
     RETURN NEW;
END;
';


--
-- TOC entry 234 (class 1255 OID 28291)
-- Name: update_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION update_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS '
  BEGIN
    NEW.UpdatedInDB := LOCALTIMESTAMP(0);
    RETURN NEW;
  END;
';


SET default_with_oids = false;

--
-- TOC entry 172 (class 1259 OID 28292)
-- Name: daemons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE daemons (
    start text NOT NULL,
    info text NOT NULL,
    id integer NOT NULL
);


--
-- TOC entry 173 (class 1259 OID 28298)
-- Name: daemons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE daemons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2301 (class 0 OID 0)
-- Dependencies: 173
-- Name: daemons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE daemons_id_seq OWNED BY daemons.id;


--
-- TOC entry 174 (class 1259 OID 28300)
-- Name: gammu; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE gammu (
    version smallint DEFAULT (0)::smallint NOT NULL,
    id integer NOT NULL
);


--
-- TOC entry 175 (class 1259 OID 28304)
-- Name: gammu_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE gammu_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2302 (class 0 OID 0)
-- Dependencies: 175
-- Name: gammu_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE gammu_id_seq OWNED BY gammu.id;


--
-- TOC entry 176 (class 1259 OID 28306)
-- Name: inbox; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE inbox (
    updatedindb timestamp(0) without time zone DEFAULT ('now'::text)::timestamp(0) without time zone NOT NULL,
    receivingdatetime timestamp(0) without time zone DEFAULT '1970-01-01 00:00:00'::timestamp without time zone NOT NULL,
    text text NOT NULL,
    sendernumber character varying(20) DEFAULT ''::character varying NOT NULL,
    coding character varying(255) DEFAULT 'Default_No_Compression'::character varying NOT NULL,
    udh text NOT NULL,
    smscnumber character varying(20) DEFAULT ''::character varying NOT NULL,
    class integer DEFAULT (-1) NOT NULL,
    textdecoded text DEFAULT ''::text NOT NULL,
    id integer NOT NULL,
    recipientid text NOT NULL,
    processed boolean DEFAULT false NOT NULL,
    CONSTRAINT inbox_coding_check CHECK (((coding)::text = ANY (ARRAY[('Default_No_Compression'::character varying)::text, ('Unicode_No_Compression'::character varying)::text, ('8bit'::character varying)::text, ('Default_Compression'::character varying)::text, ('Unicode_Compression'::character varying)::text])))
);


--
-- TOC entry 177 (class 1259 OID 28321)
-- Name: inbox_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE inbox_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2303 (class 0 OID 0)
-- Dependencies: 177
-- Name: inbox_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE inbox_id_seq OWNED BY inbox.id;


--
-- TOC entry 178 (class 1259 OID 28323)
-- Name: outbox; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE outbox (
    updatedindb timestamp(0) without time zone DEFAULT ('now'::text)::timestamp(0) without time zone NOT NULL,
    insertintodb timestamp(0) without time zone DEFAULT '1970-01-01 00:00:00'::timestamp without time zone NOT NULL,
    sendingdatetime timestamp without time zone DEFAULT '1970-01-01 00:00:00'::timestamp without time zone NOT NULL,
    text text,
    destinationnumber character varying(20) DEFAULT ''::character varying NOT NULL,
    coding character varying(255) DEFAULT 'Default_No_Compression'::character varying NOT NULL,
    udh text,
    class integer DEFAULT (-1),
    textdecoded text DEFAULT ''::text NOT NULL,
    id integer NOT NULL,
    multipart boolean DEFAULT false NOT NULL,
    relativevalidity integer DEFAULT (-1),
    senderid character varying(255),
    sendingtimeout timestamp(0) without time zone DEFAULT '1970-01-01 00:00:00'::timestamp without time zone NOT NULL,
    deliveryreport character varying(10) DEFAULT 'default'::character varying,
    creatorid text NOT NULL,
    CONSTRAINT outbox_coding_check CHECK (((coding)::text = ANY (ARRAY[('Default_No_Compression'::character varying)::text, ('Unicode_No_Compression'::character varying)::text, ('8bit'::character varying)::text, ('Default_Compression'::character varying)::text, ('Unicode_Compression'::character varying)::text]))),
    CONSTRAINT outbox_deliveryreport_check CHECK (((deliveryreport)::text = ANY (ARRAY[('default'::character varying)::text, ('yes'::character varying)::text, ('no'::character varying)::text])))
);


--
-- TOC entry 179 (class 1259 OID 28342)
-- Name: outbox_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE outbox_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2304 (class 0 OID 0)
-- Dependencies: 179
-- Name: outbox_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE outbox_id_seq OWNED BY outbox.id;


--
-- TOC entry 180 (class 1259 OID 28344)
-- Name: outbox_multipart; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE outbox_multipart (
    text text,
    coding character varying(255) DEFAULT 'Default_No_Compression'::character varying NOT NULL,
    udh text,
    class integer DEFAULT (-1),
    textdecoded text,
    id integer NOT NULL,
    sequenceposition integer DEFAULT 1 NOT NULL,
    CONSTRAINT outbox_multipart_coding_check CHECK (((coding)::text = ANY (ARRAY[('Default_No_Compression'::character varying)::text, ('Unicode_No_Compression'::character varying)::text, ('8bit'::character varying)::text, ('Default_Compression'::character varying)::text, ('Unicode_Compression'::character varying)::text])))
);


--
-- TOC entry 181 (class 1259 OID 28354)
-- Name: outbox_multipart_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE outbox_multipart_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2305 (class 0 OID 0)
-- Dependencies: 181
-- Name: outbox_multipart_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE outbox_multipart_id_seq OWNED BY outbox_multipart.id;


--
-- TOC entry 182 (class 1259 OID 28356)
-- Name: pbk; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE pbk (
    id integer NOT NULL,
    groupid integer DEFAULT (-1) NOT NULL,
    name text NOT NULL,
    number text NOT NULL
);


--
-- TOC entry 183 (class 1259 OID 28363)
-- Name: pbk_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE pbk_groups (
    name text NOT NULL,
    id integer NOT NULL
);


--
-- TOC entry 184 (class 1259 OID 28369)
-- Name: pbk_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE pbk_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2306 (class 0 OID 0)
-- Dependencies: 184
-- Name: pbk_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE pbk_groups_id_seq OWNED BY pbk_groups.id;


--
-- TOC entry 185 (class 1259 OID 28371)
-- Name: pbk_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE pbk_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2307 (class 0 OID 0)
-- Dependencies: 185
-- Name: pbk_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE pbk_id_seq OWNED BY pbk.id;


--
-- TOC entry 186 (class 1259 OID 28373)
-- Name: phones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE phones (
    id text NOT NULL,
    updatedindb timestamp(0) without time zone DEFAULT ('now'::text)::timestamp(0) without time zone NOT NULL,
    insertintodb timestamp(0) without time zone DEFAULT '1970-01-01 00:00:00'::timestamp without time zone NOT NULL,
    timeout timestamp(0) without time zone DEFAULT '1970-01-01 00:00:00'::timestamp without time zone NOT NULL,
    send boolean DEFAULT false NOT NULL,
    receive boolean DEFAULT false NOT NULL,
    imei character varying(35) NOT NULL,
    client text NOT NULL,
    battery integer DEFAULT 0 NOT NULL,
    signal integer DEFAULT 0 NOT NULL,
    sent integer DEFAULT 0 NOT NULL,
    received integer DEFAULT 0 NOT NULL
);


--
-- TOC entry 187 (class 1259 OID 28388)
-- Name: scd_accion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE scd_accion (
    id bigint NOT NULL,
    tituloaccion character varying(75) NOT NULL,
    uriaccion text,
    detalleaccion text,
    namespacetitulo character varying(150) NOT NULL,
    rol_id bigint NOT NULL
);


--
-- TOC entry 188 (class 1259 OID 28394)
-- Name: scd_accion_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE scd_accion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2308 (class 0 OID 0)
-- Dependencies: 188
-- Name: scd_accion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE scd_accion_id_seq OWNED BY scd_accion.id;


--
-- TOC entry 189 (class 1259 OID 28396)
-- Name: scd_estado; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE scd_estado (
    id bigint NOT NULL,
    nombreestado character varying(75) NOT NULL,
    detalleestado text
);


--
-- TOC entry 190 (class 1259 OID 28402)
-- Name: scd_estado_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE scd_estado_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2309 (class 0 OID 0)
-- Dependencies: 190
-- Name: scd_estado_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE scd_estado_id_seq OWNED BY scd_estado.id;


--
-- TOC entry 191 (class 1259 OID 28404)
-- Name: scd_historial_operacion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE scd_historial_operacion (
    id integer NOT NULL,
    usuario_id bigint,
    fechahisoperacion timestamp without time zone NOT NULL,
    detallehisoperacion character varying(250) NOT NULL,
    ipoperacion dominio_ip DEFAULT '''127.0.0.1''::character varying'::character varying NOT NULL
);


--
-- TOC entry 192 (class 1259 OID 28411)
-- Name: scd_historial_operacion_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE scd_historial_operacion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2310 (class 0 OID 0)
-- Dependencies: 192
-- Name: scd_historial_operacion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE scd_historial_operacion_id_seq OWNED BY scd_historial_operacion.id;


--
-- TOC entry 193 (class 1259 OID 28413)
-- Name: scd_historial_permiso; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE scd_historial_permiso (
    id bigint NOT NULL,
    finhisrol timestamp without time zone NOT NULL,
    rol_id bigint NOT NULL,
    usuario_id bigint NOT NULL
);


--
-- TOC entry 194 (class 1259 OID 28416)
-- Name: scd_historial_rol_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE scd_historial_rol_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2311 (class 0 OID 0)
-- Dependencies: 194
-- Name: scd_historial_rol_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE scd_historial_rol_id_seq OWNED BY scd_historial_permiso.id;


--
-- TOC entry 195 (class 1259 OID 28418)
-- Name: scd_localidad; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE scd_localidad (
    id bigint NOT NULL,
    nombrelocalidad character varying(150) NOT NULL,
    latlocalidad double precision NOT NULL,
    loglocalidad double precision NOT NULL,
    descripcionlocalidad text,
    localidad_id bigint,
    poblacionlocalidad bigint
);


--
-- TOC entry 196 (class 1259 OID 28424)
-- Name: scd_localidad_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE scd_localidad_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2312 (class 0 OID 0)
-- Dependencies: 196
-- Name: scd_localidad_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE scd_localidad_id_seq OWNED BY scd_localidad.id;


--
-- TOC entry 197 (class 1259 OID 28426)
-- Name: scd_otros_sms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE scd_otros_sms (
    id bigint NOT NULL,
    mensajeotrosms text NOT NULL,
    numerootrosms character varying(20) DEFAULT ''::character varying NOT NULL,
    inbox_id bigint NOT NULL,
    registrotrosms timestamp without time zone NOT NULL
);


--
-- TOC entry 198 (class 1259 OID 28433)
-- Name: scd_otros_sms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE scd_otros_sms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2313 (class 0 OID 0)
-- Dependencies: 198
-- Name: scd_otros_sms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE scd_otros_sms_id_seq OWNED BY scd_otros_sms.id;


--
-- TOC entry 199 (class 1259 OID 28435)
-- Name: scd_recibido; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE scd_recibido (
    id bigint NOT NULL,
    mensajerecibido character varying(160) NOT NULL,
    fecharecibido timestamp without time zone NOT NULL,
    usuario_id bigint NOT NULL,
    regla_id bigint NOT NULL
);


--
-- TOC entry 200 (class 1259 OID 28438)
-- Name: scd_recibido_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE scd_recibido_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2314 (class 0 OID 0)
-- Dependencies: 200
-- Name: scd_recibido_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE scd_recibido_id_seq OWNED BY scd_recibido.id;


--
-- TOC entry 201 (class 1259 OID 28440)
-- Name: scd_regla_rol; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE scd_regla_rol (
    regla_id bigint NOT NULL,
    rol_id bigint NOT NULL
);


--
-- TOC entry 202 (class 1259 OID 28443)
-- Name: scd_regla_sms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE scd_regla_sms (
    id bigint NOT NULL,
    nombreregla character varying(75) NOT NULL,
    prefijoregla character varying(10) NOT NULL,
    inicioregla timestamp without time zone NOT NULL,
    finregla timestamp without time zone NOT NULL,
    registroregla timestamp without time zone NOT NULL,
    descripcionregla character varying(250)
);


--
-- TOC entry 203 (class 1259 OID 28446)
-- Name: scd_regla_sms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE scd_regla_sms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2315 (class 0 OID 0)
-- Dependencies: 203
-- Name: scd_regla_sms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE scd_regla_sms_id_seq OWNED BY scd_regla_sms.id;


--
-- TOC entry 204 (class 1259 OID 28448)
-- Name: scd_rol; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE scd_rol (
    id integer NOT NULL,
    nombrerol character varying(75) NOT NULL,
    detallerol text
);


--
-- TOC entry 205 (class 1259 OID 28454)
-- Name: scd_rol_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE scd_rol_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2316 (class 0 OID 0)
-- Dependencies: 205
-- Name: scd_rol_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE scd_rol_id_seq OWNED BY scd_rol.id;


--
-- TOC entry 206 (class 1259 OID 28456)
-- Name: scd_usuario; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE scd_usuario (
    id bigint NOT NULL,
    username character varying(50) NOT NULL,
    password text NOT NULL,
    correousuario dominio_email NOT NULL,
    detalleusuario text,
    ultimavisitausuario timestamp without time zone NOT NULL,
    ipusuario dominio_ip DEFAULT '''127.0.0.1''::character varying'::character varying NOT NULL,
    salt text NOT NULL,
    nombreusuario character varying(150) NOT NULL,
    apellidousuario character varying(150) NOT NULL,
    telefonousuario bigint NOT NULL,
    nacimientousuario date,
    latusuario double precision NOT NULL,
    lonusuario double precision NOT NULL,
    direccionusuario text,
    sexousuario numeric(1,0) DEFAULT 0 NOT NULL,
    registrousuario timestamp without time zone NOT NULL,
    cuentausuario dominio_xml DEFAULT '<cuentas><anda>0000</anda></cuentas>'::text NOT NULL,
    estado_id bigint NOT NULL,
    localidad_id bigint NOT NULL,
    imagenusuario text
);


--
-- TOC entry 207 (class 1259 OID 28465)
-- Name: scd_usuario_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE scd_usuario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2317 (class 0 OID 0)
-- Dependencies: 207
-- Name: scd_usuario_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE scd_usuario_id_seq OWNED BY scd_usuario.id;


--
-- TOC entry 208 (class 1259 OID 28467)
-- Name: scd_usuario_rol; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE scd_usuario_rol (
    usuario_id bigint NOT NULL,
    rol_id bigint NOT NULL
);


--
-- TOC entry 209 (class 1259 OID 28470)
-- Name: sentitems; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE sentitems (
    updatedindb timestamp(0) without time zone DEFAULT ('now'::text)::timestamp(0) without time zone NOT NULL,
    insertintodb timestamp(0) without time zone DEFAULT '1970-01-01 00:00:00'::timestamp without time zone NOT NULL,
    sendingdatetime timestamp(0) without time zone DEFAULT '1970-01-01 00:00:00'::timestamp without time zone NOT NULL,
    deliverydatetime timestamp(0) without time zone,
    text text NOT NULL,
    destinationnumber character varying(20) DEFAULT ''::character varying NOT NULL,
    coding character varying(255) DEFAULT 'Default_No_Compression'::character varying NOT NULL,
    udh text NOT NULL,
    smscnumber character varying(20) DEFAULT ''::character varying NOT NULL,
    class integer DEFAULT (-1) NOT NULL,
    textdecoded text DEFAULT ''::text NOT NULL,
    id integer NOT NULL,
    senderid character varying(255) NOT NULL,
    sequenceposition integer DEFAULT 1 NOT NULL,
    status character varying(255) DEFAULT 'SendingOK'::character varying NOT NULL,
    statuserror integer DEFAULT (-1) NOT NULL,
    tpmr integer DEFAULT (-1) NOT NULL,
    relativevalidity integer DEFAULT (-1) NOT NULL,
    creatorid text NOT NULL,
    CONSTRAINT sentitems_coding_check CHECK (((coding)::text = ANY (ARRAY[('Default_No_Compression'::character varying)::text, ('Unicode_No_Compression'::character varying)::text, ('8bit'::character varying)::text, ('Default_Compression'::character varying)::text, ('Unicode_Compression'::character varying)::text]))),
    CONSTRAINT sentitems_status_check CHECK (((status)::text = ANY (ARRAY[('SendingOK'::character varying)::text, ('SendingOKNoReport'::character varying)::text, ('SendingError'::character varying)::text, ('DeliveryOK'::character varying)::text, ('DeliveryFailed'::character varying)::text, ('DeliveryPending'::character varying)::text, ('DeliveryUnknown'::character varying)::text, ('Error'::character varying)::text])))
);


--
-- TOC entry 210 (class 1259 OID 28491)
-- Name: sentitems_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE sentitems_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2318 (class 0 OID 0)
-- Dependencies: 210
-- Name: sentitems_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE sentitems_id_seq OWNED BY sentitems.id;


--
-- TOC entry 2031 (class 2604 OID 28493)
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY daemons ALTER COLUMN id SET DEFAULT nextval('daemons_id_seq'::regclass);


--
-- TOC entry 2033 (class 2604 OID 28494)
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY gammu ALTER COLUMN id SET DEFAULT nextval('gammu_id_seq'::regclass);


--
-- TOC entry 2042 (class 2604 OID 28495)
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY inbox ALTER COLUMN id SET DEFAULT nextval('inbox_id_seq'::regclass);


--
-- TOC entry 2055 (class 2604 OID 28496)
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY outbox ALTER COLUMN id SET DEFAULT nextval('outbox_id_seq'::regclass);


--
-- TOC entry 2061 (class 2604 OID 28497)
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY outbox_multipart ALTER COLUMN id SET DEFAULT nextval('outbox_multipart_id_seq'::regclass);


--
-- TOC entry 2064 (class 2604 OID 28498)
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY pbk ALTER COLUMN id SET DEFAULT nextval('pbk_id_seq'::regclass);


--
-- TOC entry 2065 (class 2604 OID 28499)
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY pbk_groups ALTER COLUMN id SET DEFAULT nextval('pbk_groups_id_seq'::regclass);


--
-- TOC entry 2075 (class 2604 OID 28500)
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_accion ALTER COLUMN id SET DEFAULT nextval('scd_accion_id_seq'::regclass);


--
-- TOC entry 2076 (class 2604 OID 28501)
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_estado ALTER COLUMN id SET DEFAULT nextval('scd_estado_id_seq'::regclass);


--
-- TOC entry 2078 (class 2604 OID 28502)
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_historial_operacion ALTER COLUMN id SET DEFAULT nextval('scd_historial_operacion_id_seq'::regclass);


--
-- TOC entry 2079 (class 2604 OID 28503)
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_historial_permiso ALTER COLUMN id SET DEFAULT nextval('scd_historial_rol_id_seq'::regclass);


--
-- TOC entry 2080 (class 2604 OID 28504)
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_localidad ALTER COLUMN id SET DEFAULT nextval('scd_localidad_id_seq'::regclass);


--
-- TOC entry 2082 (class 2604 OID 28505)
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_otros_sms ALTER COLUMN id SET DEFAULT nextval('scd_otros_sms_id_seq'::regclass);


--
-- TOC entry 2083 (class 2604 OID 28506)
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_recibido ALTER COLUMN id SET DEFAULT nextval('scd_recibido_id_seq'::regclass);


--
-- TOC entry 2084 (class 2604 OID 28507)
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_regla_sms ALTER COLUMN id SET DEFAULT nextval('scd_regla_sms_id_seq'::regclass);


--
-- TOC entry 2085 (class 2604 OID 28508)
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_rol ALTER COLUMN id SET DEFAULT nextval('scd_rol_id_seq'::regclass);


--
-- TOC entry 2089 (class 2604 OID 28509)
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_usuario ALTER COLUMN id SET DEFAULT nextval('scd_usuario_id_seq'::regclass);


--
-- TOC entry 2103 (class 2604 OID 28510)
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY sentitems ALTER COLUMN id SET DEFAULT nextval('sentitems_id_seq'::regclass);


--
-- TOC entry 2111 (class 2606 OID 28512)
-- Name: inbox_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY inbox
    ADD CONSTRAINT inbox_pkey PRIMARY KEY (id);


--
-- TOC entry 2117 (class 2606 OID 28514)
-- Name: outbox_multipart_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY outbox_multipart
    ADD CONSTRAINT outbox_multipart_pkey PRIMARY KEY (id, sequenceposition);


--
-- TOC entry 2114 (class 2606 OID 28516)
-- Name: outbox_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY outbox
    ADD CONSTRAINT outbox_pkey PRIMARY KEY (id);


--
-- TOC entry 2121 (class 2606 OID 28518)
-- Name: pbk_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pbk_groups
    ADD CONSTRAINT pbk_groups_pkey PRIMARY KEY (id);


--
-- TOC entry 2119 (class 2606 OID 28520)
-- Name: pbk_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pbk
    ADD CONSTRAINT pbk_pkey PRIMARY KEY (id);


--
-- TOC entry 2123 (class 2606 OID 28522)
-- Name: phones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phones
    ADD CONSTRAINT phones_pkey PRIMARY KEY (imei);


--
-- TOC entry 2107 (class 2606 OID 28524)
-- Name: pk_deamons; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY daemons
    ADD CONSTRAINT pk_deamons PRIMARY KEY (id);


--
-- TOC entry 2127 (class 2606 OID 28526)
-- Name: pk_estado; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_estado
    ADD CONSTRAINT pk_estado PRIMARY KEY (id);


--
-- TOC entry 2109 (class 2606 OID 28528)
-- Name: pk_gammu; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY gammu
    ADD CONSTRAINT pk_gammu PRIMARY KEY (id);


--
-- TOC entry 2135 (class 2606 OID 28530)
-- Name: pk_localidad; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_localidad
    ADD CONSTRAINT pk_localidad PRIMARY KEY (id);


--
-- TOC entry 2137 (class 2606 OID 28532)
-- Name: pk_otros_sms; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_otros_sms
    ADD CONSTRAINT pk_otros_sms PRIMARY KEY (id);


--
-- TOC entry 2139 (class 2606 OID 28534)
-- Name: pk_recibido; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_recibido
    ADD CONSTRAINT pk_recibido PRIMARY KEY (id);


--
-- TOC entry 2143 (class 2606 OID 28536)
-- Name: pk_regla; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_regla_sms
    ADD CONSTRAINT pk_regla PRIMARY KEY (id);


--
-- TOC entry 2141 (class 2606 OID 28538)
-- Name: pk_regla_rol; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_regla_rol
    ADD CONSTRAINT pk_regla_rol PRIMARY KEY (regla_id, rol_id);


--
-- TOC entry 2149 (class 2606 OID 28540)
-- Name: pk_saf_rol; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_rol
    ADD CONSTRAINT pk_saf_rol PRIMARY KEY (id);


--
-- TOC entry 2125 (class 2606 OID 28542)
-- Name: pk_scd_accion; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_accion
    ADD CONSTRAINT pk_scd_accion PRIMARY KEY (id);


--
-- TOC entry 2131 (class 2606 OID 28544)
-- Name: pk_scd_bitacora; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_historial_operacion
    ADD CONSTRAINT pk_scd_bitacora PRIMARY KEY (id);


--
-- TOC entry 2133 (class 2606 OID 28546)
-- Name: pk_scd_historial_permiso; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_historial_permiso
    ADD CONSTRAINT pk_scd_historial_permiso PRIMARY KEY (id);


--
-- TOC entry 2153 (class 2606 OID 28548)
-- Name: pk_usuario; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_usuario
    ADD CONSTRAINT pk_usuario PRIMARY KEY (id);


--
-- TOC entry 2159 (class 2606 OID 28550)
-- Name: pk_usuario_rol; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_usuario_rol
    ADD CONSTRAINT pk_usuario_rol PRIMARY KEY (usuario_id, rol_id);


--
-- TOC entry 2129 (class 2606 OID 28552)
-- Name: scd_estado_nombreestado_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_estado
    ADD CONSTRAINT scd_estado_nombreestado_key UNIQUE (nombreestado);


--
-- TOC entry 2151 (class 2606 OID 28554)
-- Name: scd_rol_nombrerol_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_rol
    ADD CONSTRAINT scd_rol_nombrerol_key UNIQUE (nombrerol);


--
-- TOC entry 2163 (class 2606 OID 28556)
-- Name: sentitems_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY sentitems
    ADD CONSTRAINT sentitems_pkey PRIMARY KEY (id, sequenceposition);


--
-- TOC entry 2155 (class 2606 OID 28558)
-- Name: unique_correo; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_usuario
    ADD CONSTRAINT unique_correo UNIQUE (correousuario);


--
-- TOC entry 2157 (class 2606 OID 28560)
-- Name: unique_login; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_usuario
    ADD CONSTRAINT unique_login UNIQUE (username);


--
-- TOC entry 2145 (class 2606 OID 28562)
-- Name: unique_nombre_regla; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_regla_sms
    ADD CONSTRAINT unique_nombre_regla UNIQUE (nombreregla);


--
-- TOC entry 2147 (class 2606 OID 28564)
-- Name: unique_patron_regla; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_regla_sms
    ADD CONSTRAINT unique_patron_regla UNIQUE (prefijoregla);


--
-- TOC entry 2112 (class 1259 OID 28565)
-- Name: outbox_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX outbox_date ON outbox USING btree (sendingdatetime, sendingtimeout);


--
-- TOC entry 2115 (class 1259 OID 28566)
-- Name: outbox_sender; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX outbox_sender ON outbox USING btree (senderid);


--
-- TOC entry 2160 (class 1259 OID 28567)
-- Name: sentitems_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sentitems_date ON sentitems USING btree (deliverydatetime);


--
-- TOC entry 2161 (class 1259 OID 28568)
-- Name: sentitems_dest; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sentitems_dest ON sentitems USING btree (destinationnumber);


--
-- TOC entry 2164 (class 1259 OID 28569)
-- Name: sentitems_sender; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sentitems_sender ON sentitems USING btree (senderid);


--
-- TOC entry 2165 (class 1259 OID 28570)
-- Name: sentitems_tpmr; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sentitems_tpmr ON sentitems USING btree (tpmr);


--
-- TOC entry 2178 (class 2620 OID 28571)
-- Name: filtra_sms_recivido; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER filtra_sms_recivido BEFORE INSERT ON inbox FOR EACH ROW EXECUTE PROCEDURE filtra_sms_recivido();


--
-- TOC entry 2182 (class 2620 OID 28572)
-- Name: guarda_estado; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER guarda_estado BEFORE DELETE OR UPDATE ON scd_estado FOR EACH ROW EXECUTE PROCEDURE guarda_estado();


--
-- TOC entry 2183 (class 2620 OID 28573)
-- Name: nueva_regla; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER nueva_regla BEFORE INSERT ON scd_regla_sms FOR EACH ROW EXECUTE PROCEDURE nueva_regla();

ALTER TABLE scd_regla_sms DISABLE TRIGGER nueva_regla;


--
-- TOC entry 2179 (class 2620 OID 28574)
-- Name: update_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_timestamp BEFORE UPDATE ON inbox FOR EACH ROW EXECUTE PROCEDURE update_timestamp();


--
-- TOC entry 2180 (class 2620 OID 28575)
-- Name: update_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_timestamp BEFORE UPDATE ON outbox FOR EACH ROW EXECUTE PROCEDURE update_timestamp();


--
-- TOC entry 2181 (class 2620 OID 28576)
-- Name: update_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_timestamp BEFORE UPDATE ON phones FOR EACH ROW EXECUTE PROCEDURE update_timestamp();


--
-- TOC entry 2184 (class 2620 OID 28577)
-- Name: update_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_timestamp BEFORE UPDATE ON sentitems FOR EACH ROW EXECUTE PROCEDURE update_timestamp();


--
-- TOC entry 2175 (class 2606 OID 28578)
-- Name: fk_estado_usuario; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_usuario
    ADD CONSTRAINT fk_estado_usuario FOREIGN KEY (estado_id) REFERENCES scd_estado(id) MATCH FULL ON UPDATE CASCADE ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 2170 (class 2606 OID 28583)
-- Name: fk_localidad; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_localidad
    ADD CONSTRAINT fk_localidad FOREIGN KEY (localidad_id) REFERENCES scd_localidad(id) MATCH FULL ON UPDATE CASCADE ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 2174 (class 2606 OID 28588)
-- Name: fk_localidad_usuario; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_usuario
    ADD CONSTRAINT fk_localidad_usuario FOREIGN KEY (localidad_id) REFERENCES scd_localidad(id) MATCH FULL ON UPDATE CASCADE ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 2172 (class 2606 OID 28593)
-- Name: fk_regla; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_regla_rol
    ADD CONSTRAINT fk_regla FOREIGN KEY (regla_id) REFERENCES scd_regla_sms(id) MATCH FULL ON UPDATE CASCADE ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 2176 (class 2606 OID 28598)
-- Name: fk_rol; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_usuario_rol
    ADD CONSTRAINT fk_rol FOREIGN KEY (rol_id) REFERENCES scd_rol(id) MATCH FULL ON UPDATE CASCADE ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 2173 (class 2606 OID 28603)
-- Name: fk_rol; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_regla_rol
    ADD CONSTRAINT fk_rol FOREIGN KEY (rol_id) REFERENCES scd_rol(id) MATCH FULL ON UPDATE CASCADE ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 2166 (class 2606 OID 28608)
-- Name: fk_scd_accion; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_accion
    ADD CONSTRAINT fk_scd_accion FOREIGN KEY (rol_id) REFERENCES scd_rol(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2177 (class 2606 OID 28613)
-- Name: fk_usuario; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_usuario_rol
    ADD CONSTRAINT fk_usuario FOREIGN KEY (usuario_id) REFERENCES scd_usuario(id) MATCH FULL ON UPDATE CASCADE ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 2171 (class 2606 OID 28618)
-- Name: fk_usuario; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_recibido
    ADD CONSTRAINT fk_usuario FOREIGN KEY (usuario_id) REFERENCES scd_usuario(id) MATCH FULL ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2168 (class 2606 OID 28623)
-- Name: historial_rol; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_historial_permiso
    ADD CONSTRAINT historial_rol FOREIGN KEY (rol_id) REFERENCES scd_rol(id) MATCH FULL ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2169 (class 2606 OID 28628)
-- Name: historial_usuario; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_historial_permiso
    ADD CONSTRAINT historial_usuario FOREIGN KEY (usuario_id) REFERENCES scd_usuario(id) MATCH FULL ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2167 (class 2606 OID 28633)
-- Name: usuario; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_historial_operacion
    ADD CONSTRAINT usuario FOREIGN KEY (usuario_id) REFERENCES scd_usuario(id) MATCH FULL ON UPDATE CASCADE ON DELETE RESTRICT;


-- Completed on 2015-09-23 17:38:16 CST

--
-- PostgreSQL database dump complete
--

