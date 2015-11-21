--
-- PostgreSQL database dump
--

-- Dumped from database version 9.4.5
-- Dumped by pg_dump version 9.4.5
-- Started on 2015-11-20 22:49:05 CST

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- TOC entry 209 (class 3079 OID 11861)
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- TOC entry 2303 (class 0 OID 0)
-- Dependencies: 209
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- TOC entry 622 (class 1247 OID 30586)
-- Name: dominio_email; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN dominio_email AS character varying(150)
	CONSTRAINT dominio_email_check CHECK (((VALUE)::text ~ '^[A-Za-z0-9](([_.-]?[a-zA-Z0-9]+)*)@([A-Za-z0-9]+)(([.-]?[a-zA-Z0-9]+)*).([A-Za-z]{2,})$'::text));


--
-- TOC entry 624 (class 1247 OID 30588)
-- Name: dominio_ip; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN dominio_ip AS character varying(15)
	CONSTRAINT dominio_ip_check CHECK ((((VALUE)::inet > '0.0.0.0'::inet) AND ((VALUE)::inet < '223.255.255.255'::inet)));


--
-- TOC entry 626 (class 1247 OID 30590)
-- Name: dominio_xml; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN dominio_xml AS text
	CONSTRAINT dominio_xml_check CHECK ((VALUE)::xml IS DOCUMENT);


--
-- TOC entry 223 (class 1255 OID 30592)
-- Name: adduser(text, text, text, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION adduser(text, text, text, bigint) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
/**
 * Funcion que registra un usuario del sistema,
 * se activa por envio de mensajes de texto (sms)
 * 
 * Acceso: publico
 * Autor:  William Vides - wilx.sv@gmail.com
 * Fecha: 2012.04.11
 * Elemplo: SELECT adduser('USER-1', 'un nombre', 'un apellido', 79797373);
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
    VALUES (v_username, 'n/a', v_username||'@local.lo', 'usuario registrado desde telefono', now()::timestamp(0) without time zone, 
            '127.0.0.1', 'n/a', v_nombre, v_apellido, v_telefono, 
            now()::date - 365*18, 13.704032, -89.188385, 'n/a', 
            0, now()::timestamp(0) without time zone, 3, 1);
    RAISE INFO ' :: Usuario [%] registrado con exito :: ', v_username;
    RETURN 1;
END;
$_$;


--
-- TOC entry 235 (class 1255 OID 31387)
-- Name: completa_mensaje(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION completa_mensaje(text, text) RETURNS text
    LANGUAGE plpgsql
    AS $_$
/**
 * Completa el mensaje con agregando al final el numero de quien envia el mensaje.
 * 
 * Acceso: publico
 * Autor:  William Vides - wilx.sv@gmail.com
 * Fecha: 2015.11.20
 *
*/

DECLARE
    mensaje ALIAS FOR $1;
    numero ALIAS FOR $2;
 BEGIN
    RETURN mensaje|| ' --' ||get_alias(numero);
END;
$_$;


--
-- TOC entry 241 (class 1255 OID 31323)
-- Name: ejecuta_regla(text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION ejecuta_regla(text, text, text) RETURNS text
    LANGUAGE plpgsql
    AS $_$
/**
 * Ejecucion dinamica de una funcion a partir de un texto 
 * 
 * Acceso: publico
 * Autor:  William Vides - wilx.sv@gmail.com
 * Fecha: 2015.10.22
 * Retorno: '0' = Problemas encontrados en la ejecucion de la funcion; '1' = Funcion correcta
*/
DECLARE
    regla ALIAS FOR $1;
    mensaje ALIAS FOR $2;
    numero ALIAS FOR $3;
    v_resultado text;
BEGIN
    RAISE INFO ' :: ejecuta [%] :: ', $1;
    EXECUTE 'SELECT '||  $1  ||' FROM ' ||  $1  || '(''' || $2 || ''', ''' || $3  ||''')'  INTO v_resultado;
        
    RETURN v_resultado;

    EXCEPTION
        WHEN invalid_text_representation THEN
            RETURN '';
END;
$_$;


--
-- TOC entry 229 (class 1255 OID 30593)
-- Name: enviar_sms(bigint, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION enviar_sms(bigint, text) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
/**
 * Funcion que registra un sms a enviar
 * 
 * Acceso: publico
 * Autor:  William Vides - wilx.sv@gmail.com
 * Fecha: 2012.10.10
 * Elemplo: 
 *
*/
DECLARE
    numero ALIAS FOR $1;
    mensaje ALIAS FOR $2;
    v_numero text;
BEGIN
    SELECT * INTO v_numero FROM CAST(numero AS text);
    INSERT INTO outbox("DestinationNumber", "TextDecoded", "CreatorID")
    VALUES ('+'||v_numero, mensaje,'Gammu 1.33.0-3');

    RAISE INFO ' :: Salida de mensaje registrada con exito :: ';
    RETURN 1;
END;
$_$;


--
-- TOC entry 232 (class 1255 OID 30797)
-- Name: enviar_todas(text, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION enviar_todas(text, bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $_$
/**
 * Envia un mensaje recivido a todas
 * 
 * Acceso: publico
 * Autor:  William Vides - wilx.sv@gmail.com
 * Fecha: 2015.10.10
 *
*/
DECLARE
    mensaje ALIAS FOR $1;
    numero ALIAS FOR $2;
    v_result integer;
    r scd_usuario%rowtype;
BEGIN

    FOR r IN SELECT * FROM scd_usuario WHERE telefonousuario != numero
    LOOP
        v_result := enviar_sms(r.telefonousuario, mensaje);
        -- can do some processing here
        --RETURN NEXT r; -- return current row of SELECT
    END LOOP;

    RETURN 1;

    EXCEPTION
        WHEN invalid_text_representation THEN
            RETURN 0;
END;
$_$;


--
-- TOC entry 239 (class 1255 OID 30594)
-- Name: filtra_sms_recivido(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION filtra_sms_recivido() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
/**
 * Funcion que filtra tuplas en base a una cadena de texto y a un prefijo,
 * si se encuentra el prefijo, el mensaje es enviado a la funcion con ese nombre,
 * el mensaje es recibido si lo permiten las reglas, si no es enviado a XXX
 * 
 * Acceso: publico
 * Autor:  William Vides - wilx.sv@gmail.com
 * Fecha: 2015.10.22
 *
*/
DECLARE
    v_item RECORD;
    v_id text;
BEGIN
    IF (TG_OP = 'INSERT') THEN
        v_id := msg_es_valido(NEW."TextDecoded", NEW."SenderNumber");
        IF (v_id NOTNULL AND v_id <> '' ) THEN
            v_id = ejecuta_regla(v_id, NEW."TextDecoded", NEW."SenderNumber");
            IF (v_id <> '0') THEN
                SELECT id INTO v_id FROM scd_regla_sms WHERE prefijoregla = prefijo(NEW."TextDecoded");
                INSERT INTO scd_recibido(mensajerecibido, fecharecibido, usuario_id, regla_id) VALUES 
                (NEW."TextDecoded", NEW."ReceivingDateTime"::timestamp(0) without time zone, get_id_usuario(get_numero(NEW."SenderNumber")), v_id::BIGINT);
            ELSE
            END IF;
        ELSE
            RAISE INFO ' :: Operacion invalida, regla no tiene asociada una funcion [%] :: ', v_id;
            --Registro de mensajes en tabla de sms_otros
            SELECT last_value INTO v_id FROM "inbox_ID_seq";
            INSERT INTO scd_otros_sms(mensajeotrosms, numerootrosms, inbox_id, registrotrosms)
            VALUES (NEW."TextDecoded", NEW."SenderNumber", v_id::BIGINT, NEW."ReceivingDateTime"::timestamp(0) without time zone);
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


--
-- TOC entry 237 (class 1255 OID 31388)
-- Name: get_alias(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_alias(text) RETURNS text
    LANGUAGE plpgsql
    AS $_$
/**
 * Funcion que retorna el alias de una usuaria
 * 
 * Acceso: publico
 * Autor:  William Vides - wilx.sv@gmail.com
 * Fecha: 2015.11.20
 *
*/
DECLARE
    numero ALIAS FOR $1;
    alias TEXT;
BEGIN
    SELECT username INTO alias FROM scd_usuario WHERE telefonousuario = get_numero(numero);
    RETURN alias;
    EXCEPTION
        WHEN invalid_text_representation THEN
            RETURN '';
END;
$_$;


--
-- TOC entry 224 (class 1255 OID 30595)
-- Name: get_id_usuario(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_id_usuario(bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $_$
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
        RAISE INFO ' :: Usuario registrado [Telefono con registro asociado en el catalogo de usuarios] :: ';
        RETURN v_item.id;
     ELSE
        RAISE INFO ' :: Usuario no registrado [Telefono sin registro asociado en el catalogo de usuarios] :: ';
        RETURN 0;
     END IF;
END  
$_$;


--
-- TOC entry 225 (class 1255 OID 30596)
-- Name: get_numero(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_numero(text) RETURNS bigint
    LANGUAGE plpgsql
    AS $_$
/**
 * Funcion que retorna un numero, si recibe un alfanumerico retorna 0
 * 
 * Acceso: publico
 * Autor:  William Vides - wilx.sv@gmail.com
 * Fecha: 2012.04.11
 * Elemplo: SELECT * FROM get_numero('79797373');
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
$_$;


--
-- TOC entry 226 (class 1255 OID 30597)
-- Name: guarda_estado(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION guarda_estado() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
     IF (TG_OP = 'UPDATE') THEN
         IF (NEW.nombreestado <> OLD.nombreestado OR NEW.id <> OLD.id) THEN
             RAISE EXCEPTION ' :: Operacion invalida, nombreestado sin modificaciones :: ';
             RETURN OLD;
         END IF;
     END IF;
     IF (TG_OP = 'DELETE') THEN
         RAISE EXCEPTION ' :: Operacion invalida, estado sin eliminarse :: ';
         RETURN NULL;
     END IF;
END;
$$;


--
-- TOC entry 236 (class 1255 OID 31360)
-- Name: info(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION info(amensaje text, atelefono text) RETURNS text
    LANGUAGE plpgsql
    AS $$

DECLARE
    v_result integer;
    v_mensaje text;
    r scd_usuario%rowtype;

BEGIN
 v_mensaje := completa_mensaje(amensaje, atelefono);
 FOR r IN SELECT * FROM scd_usuario WHERE telefonousuario != atelefono::BIGINT and estado_id > 1
    LOOP
        v_result := enviar_sms(r.telefonousuario, v_mensaje);
    
    END LOOP;
 RETURN '1';

END;
$$;


--
-- TOC entry 233 (class 1255 OID 31335)
-- Name: md(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION md(amensaje text, atelefono text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_id integer;
  r scd_usuario%rowtype;  
  v_encontrado int;
  v_result integer;
  v_mensaje text;
BEGIN
 v_mensaje := completa_mensaje(amensaje, atelefono);
 FOR r IN SELECT * FROM scd_usuario --WHERE telefonousuario != numero
    LOOP
       v_encontrado := position(r.username in amensaje );
       if(v_encontrado!=0) then
	v_result := enviar_sms(r.telefonousuario, v_mensaje);
       end if; 
    END LOOP;
 RETURN '1';
END;
$$;


--
-- TOC entry 238 (class 1255 OID 31322)
-- Name: msg_es_valido(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION msg_es_valido(text, text) RETURNS text
    LANGUAGE plpgsql
    AS $_$
/**
 * Evalua si un mensaje es valido para ser recivido y guardado en recividos 
 * 
 * Acceso: publico
 * Autor:  William Vides - wilx.sv@gmail.com
 * Fecha: 2015.10.10
 * Ejemplo: msg_es_valido()
 * Retorno: 0 = Problemas encontrados en el mensaje recibido ; 1 = Mensaje correcto
*/
DECLARE
    mensaje ALIAS FOR $1;
    numero ALIAS FOR $2;
    v_item BIGINT;
    v_id BIGINT;
    prefijo text;
BEGIN
    RAISE INFO ' :: Inicia msg valido :: ';
    v_id := get_id_usuario(get_numero(numero));
    prefijo := prefijo(mensaje);
    -- usuaria valida estado > 1
    -- regla_rol posea regla_sms
    -- regla valida inicioregla <= now() <= finregla
    SELECT * INTO v_item
        FROM     scd_usuario us, scd_usuario_rol ur, scd_regla_rol rr, scd_regla_sms rs
        WHERE    us.id = v_id AND us.estado_id > 1 AND ur.rol_id = rr.rol_id 
	         AND rr.regla_id = rs.id AND rs.prefijoregla = prefijo
                 AND rs.inicioregla <= now() AND finregla >= now();
    IF (v_item NOTNULL) THEN
        RAISE INFO ' :: Inicia msg valido :: %', prefijo;
        RETURN prefijo;
    ELSE
        RAISE INFO ' :: Invalido :: %', prefijo;
        RETURN '';
    END IF;
    
    EXCEPTION
        WHEN invalid_text_representation THEN
            RETURN '';
END;
$_$;


--
-- TOC entry 227 (class 1255 OID 30598)
-- Name: nueva_regla(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION nueva_regla() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
     IF (TG_OP = 'INSERT') THEN
         SELECT * INTO v_item FROM pg_proc proc JOIN pg_language lang ON proc.prolang = lang.oid
                  WHERE proc.proname = NEW.prefijoregla;/*AND lang.lanname = 'plpgsql'*/
         IF (v_item NOTNULL) THEN
             RAISE INFO ' :: Operacion asociada a regla :: ';
             RETURN NEW;
         ELSE
             RAISE EXCEPTION ' :: Operacion invalida, regla no tiene asociada una funcion :: ';
             RETURN NULL;
         END IF;
     END IF;
END;
$$;


--
-- TOC entry 228 (class 1255 OID 30599)
-- Name: prefijo(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION prefijo(text) RETURNS text
    LANGUAGE plpgsql
    AS $_$
/**
 * Funcion que retorna la primer palabra en minusculas de una cadena enviada
 * 
 * Acceso: publico
 * Autor:  William Vides - wilx.sv@gmail.com
 * Fecha: 2012.04.11
 * Elemplo: SELECT * FROM prefijo(' palabra de ejemplo'); - Retorna 'palabra'
 *
*/
DECLARE
    mensaje ALIAS FOR $1;
    v_prefijo text;
    v_limite INTEGER;
BEGIN
    SELECT * INTO v_limite FROM position(' ' in lower(mensaje));
    RAISE INFO 'Limite % de %', v_limite, $1;--
    IF (v_limite-1 < 0) THEN 
        v_limite := char_length($1);
    ELSE
        v_limite := v_limite - 1;
    END IF;
    SELECT * INTO v_prefijo FROM substring(trim(lower(mensaje)) from 1 for v_limite);
    RETURN v_prefijo;
END;
$_$;


--
-- TOC entry 234 (class 1255 OID 31349)
-- Name: pvs(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION pvs(text, text) RETURNS text
    LANGUAGE plpgsql
    AS $_$
/**
 * Envia un mensaje con el protocolo de atencion a una victima de violencia sexual
 * 
 * Acceso: publico
 * Autor:  William Vides - wilx.sv@gmail.com
 * Fecha: 2015.10.22
 *
*/

DECLARE
    mensaje ALIAS FOR $1;
    numero ALIAS FOR $2;
    v_numero BIGINT;
    v_msg TEXT;
    var integer;
BEGIN
    RAISE INFO 'Inicia pvs';
    --v_msg := regexp_replace(trim($1), '%'||trim(prefijo($1))||' ', '');
    v_msg := trim(both prefijo(lower($1)) from lower($1));
    v_numero := get_numero(v_msg);
    RAISE INFO 'palabra % : mensaje %',prefijo($1), v_numero;

    IF (v_numero > 0) THEN
       IF (v_numero < 99999999) THEN
           v_numero := (('503'||v_numero::text)::BIGINT);
       END IF;
       var := enviar_sms(v_numero, 'No te bañes, Acude a Fiscalia, exige la pildora de anticoncepcion de emergencia y retrovirales.');
--        var := enviar_sms(v_numero, '');
  --      var := enviar_sms(v_numero, '');
        RETURN '1';
    ELSE
        v_numero := get_numero($2);
    --    var := enviar_sms(v_numero, '');
      --  var := enviar_sms(v_numero, '');
        var := enviar_sms(v_numero, 'No te bañes, Acude a Fiscalia, exige la pildora de anticoncepcion de emergencia y retrovirales.');
        RETURN '';
    END IF;
    RETURN '0';
END;
$_$;


--
-- TOC entry 240 (class 1255 OID 31359)
-- Name: rcu(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rcu(amensaje text, atelefono text) RETURNS text
    LANGUAGE plpgsql
    AS $$

DECLARE
    v_mensaje text;
    v_result integer;
    r scd_usuario%rowtype;
BEGIN
 v_mensaje := completa_mensaje(amensaje, atelefono);
 FOR r IN SELECT * FROM scd_usuario WHERE telefonousuario != atelefono::BIGINT and estado_id > 1
    LOOP
        v_result := enviar_sms(r.telefonousuario, v_mensaje);
    END LOOP;
 RETURN '1';
END;
$$;


--
-- TOC entry 230 (class 1255 OID 30600)
-- Name: registrame(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION registrame(text, text) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
/**
 * Funcion que registra a un usuario del sistema
 * se recibe un numero y una cadena, si el telefono existe no se registra,
 * si no, se evalua el formato con el nombre eviado y se generan los campos
 * adicionales al usuario
 * 
 * Acceso: publico
 * Autor:  William Vides - wilx.sv@gmail.com
 * Fecha: 2012.04.11
 * Elemplo: SELECT * FROM registrame(79797373, 'registrame juan ernesto-mira alvarez');
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
            SELECT * INTO v_limite FROM position(' ' in trim(lower(mensaje)));
            SELECT * INTO v_longitud FROM char_length(trim(lower(mensaje)));
            SELECT * INTO v_mensaje FROM substring(trim(lower(mensaje)) from v_limite+1 for v_longitud);-- mensaje sin prefijo de registro
            SELECT * INTO v_limite FROM position('-' in v_mensaje);
            IF v_limite > 0 THEN
                SELECT * INTO v_nombre FROM substring(v_mensaje from 1 for v_limite-1);--asignacion de nombre
                SELECT * INTO v_apellido FROM substring(v_mensaje from v_limite+1 for v_longitud);--asignacion de apellido
                SELECT * INTO v_r FROM scd_usuario_id_seq;
                v_usr := 'usuario-'||v_r.last_value;
                v_limite := adduser(v_usr, v_nombre, v_apellido, v_telefono);
                RAISE INFO ' :: Usuario [%] registrado con exito :: ', v_r.last_value;
                v_limite := enviar_sms(v_telefono, 'Bienvenido, ya formas parte del sistema de comunicacion digital comunitaria');
                RETURN v_r.last_value;
            ELSE
                RAISE NOTICE ' :: Usuario no registrado [formato incorrecto de nombre y apellido] :: ';
                v_limite := enviar_sms(v_telefono, 'Intenta de nuevo y envia correctamente el mensaje. El formato de registro es "registrame y tu nombre", ejemplo: "registrame Oscar Arnulfo-Romero Galdamez"');
                RETURN 0;
            END IF;
        ELSE
           RAISE INFO ' :: No se registrara este telefono :: ';
           RETURN 0;
        END IF;
    ELSE
        RAISE INFO ' :: Usuario no registrado [formato incorrecto de telefono] :: ';
        RETURN 0;
    END IF;
END;
$_$;


--
-- TOC entry 231 (class 1255 OID 30601)
-- Name: set_namespace(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION set_namespace() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
     NEW.namespacetitulo = REPLACE(NEW.namespacetitulo, E'\\\\', '');
     RETURN NEW;
END;
$$;


--
-- TOC entry 210 (class 1255 OID 30437)
-- Name: update_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION update_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    NEW."UpdatedInDB" := LOCALTIMESTAMP(0);
    RETURN NEW;
  END;
$$;


SET default_with_oids = false;

--
-- TOC entry 172 (class 1259 OID 30438)
-- Name: daemons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE daemons (
    "Start" text NOT NULL,
    "Info" text NOT NULL
);


--
-- TOC entry 173 (class 1259 OID 30444)
-- Name: gammu; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE gammu (
    "Version" smallint DEFAULT 0::smallint NOT NULL
);


--
-- TOC entry 175 (class 1259 OID 30450)
-- Name: inbox; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE inbox (
    "UpdatedInDB" timestamp(0) without time zone DEFAULT ('now'::text)::timestamp(0) without time zone NOT NULL,
    "ReceivingDateTime" timestamp(0) without time zone DEFAULT ('now'::text)::timestamp(0) without time zone NOT NULL,
    "Text" text NOT NULL,
    "SenderNumber" character varying(20) DEFAULT ''::character varying NOT NULL,
    "Coding" character varying(255) DEFAULT 'Default_No_Compression'::character varying NOT NULL,
    "UDH" text NOT NULL,
    "SMSCNumber" character varying(20) DEFAULT ''::character varying NOT NULL,
    "Class" integer DEFAULT (-1) NOT NULL,
    "TextDecoded" text DEFAULT ''::text NOT NULL,
    "ID" integer NOT NULL,
    "RecipientID" text NOT NULL,
    "Processed" boolean DEFAULT false NOT NULL,
    CONSTRAINT "inbox_Coding_check" CHECK ((("Coding")::text = ANY ((ARRAY['Default_No_Compression'::character varying, 'Unicode_No_Compression'::character varying, '8bit'::character varying, 'Default_Compression'::character varying, 'Unicode_Compression'::character varying])::text[])))
);


--
-- TOC entry 174 (class 1259 OID 30448)
-- Name: inbox_ID_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "inbox_ID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2304 (class 0 OID 0)
-- Dependencies: 174
-- Name: inbox_ID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "inbox_ID_seq" OWNED BY inbox."ID";


--
-- TOC entry 177 (class 1259 OID 30471)
-- Name: outbox; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE outbox (
    "UpdatedInDB" timestamp(0) without time zone DEFAULT ('now'::text)::timestamp(0) without time zone NOT NULL,
    "InsertIntoDB" timestamp(0) without time zone DEFAULT ('now'::text)::timestamp(0) without time zone NOT NULL,
    "SendingDateTime" timestamp without time zone DEFAULT ('now'::text)::timestamp(0) without time zone NOT NULL,
    "SendBefore" time without time zone DEFAULT '23:59:59'::time without time zone NOT NULL,
    "SendAfter" time without time zone DEFAULT '00:00:00'::time without time zone NOT NULL,
    "Text" text,
    "DestinationNumber" character varying(20) DEFAULT ''::character varying NOT NULL,
    "Coding" character varying(255) DEFAULT 'Default_No_Compression'::character varying NOT NULL,
    "UDH" text,
    "Class" integer DEFAULT (-1),
    "TextDecoded" text DEFAULT ''::text NOT NULL,
    "ID" integer NOT NULL,
    "MultiPart" boolean DEFAULT false NOT NULL,
    "RelativeValidity" integer DEFAULT (-1),
    "SenderID" character varying(255),
    "SendingTimeOut" timestamp(0) without time zone DEFAULT ('now'::text)::timestamp(0) without time zone NOT NULL,
    "DeliveryReport" character varying(10) DEFAULT 'default'::character varying,
    "CreatorID" text NOT NULL,
    CONSTRAINT "outbox_Coding_check" CHECK ((("Coding")::text = ANY ((ARRAY['Default_No_Compression'::character varying, 'Unicode_No_Compression'::character varying, '8bit'::character varying, 'Default_Compression'::character varying, 'Unicode_Compression'::character varying])::text[]))),
    CONSTRAINT "outbox_DeliveryReport_check" CHECK ((("DeliveryReport")::text = ANY ((ARRAY['default'::character varying, 'yes'::character varying, 'no'::character varying])::text[])))
);


--
-- TOC entry 176 (class 1259 OID 30469)
-- Name: outbox_ID_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "outbox_ID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2305 (class 0 OID 0)
-- Dependencies: 176
-- Name: outbox_ID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "outbox_ID_seq" OWNED BY outbox."ID";


--
-- TOC entry 179 (class 1259 OID 30500)
-- Name: outbox_multipart; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE outbox_multipart (
    "Text" text,
    "Coding" character varying(255) DEFAULT 'Default_No_Compression'::character varying NOT NULL,
    "UDH" text,
    "Class" integer DEFAULT (-1),
    "TextDecoded" text,
    "ID" integer NOT NULL,
    "SequencePosition" integer DEFAULT 1 NOT NULL,
    CONSTRAINT "outbox_multipart_Coding_check" CHECK ((("Coding")::text = ANY ((ARRAY['Default_No_Compression'::character varying, 'Unicode_No_Compression'::character varying, '8bit'::character varying, 'Default_Compression'::character varying, 'Unicode_Compression'::character varying])::text[])))
);


--
-- TOC entry 178 (class 1259 OID 30498)
-- Name: outbox_multipart_ID_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "outbox_multipart_ID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2306 (class 0 OID 0)
-- Dependencies: 178
-- Name: outbox_multipart_ID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "outbox_multipart_ID_seq" OWNED BY outbox_multipart."ID";


--
-- TOC entry 181 (class 1259 OID 30515)
-- Name: pbk; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE pbk (
    "ID" integer NOT NULL,
    "GroupID" integer DEFAULT (-1) NOT NULL,
    "Name" text NOT NULL,
    "Number" text NOT NULL
);


--
-- TOC entry 180 (class 1259 OID 30513)
-- Name: pbk_ID_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "pbk_ID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2307 (class 0 OID 0)
-- Dependencies: 180
-- Name: pbk_ID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "pbk_ID_seq" OWNED BY pbk."ID";


--
-- TOC entry 183 (class 1259 OID 30527)
-- Name: pbk_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE pbk_groups (
    "Name" text NOT NULL,
    "ID" integer NOT NULL
);


--
-- TOC entry 182 (class 1259 OID 30525)
-- Name: pbk_groups_ID_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "pbk_groups_ID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2308 (class 0 OID 0)
-- Dependencies: 182
-- Name: pbk_groups_ID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "pbk_groups_ID_seq" OWNED BY pbk_groups."ID";


--
-- TOC entry 184 (class 1259 OID 30536)
-- Name: phones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE phones (
    "ID" text NOT NULL,
    "UpdatedInDB" timestamp(0) without time zone DEFAULT ('now'::text)::timestamp(0) without time zone NOT NULL,
    "InsertIntoDB" timestamp(0) without time zone DEFAULT ('now'::text)::timestamp(0) without time zone NOT NULL,
    "TimeOut" timestamp(0) without time zone DEFAULT ('now'::text)::timestamp(0) without time zone NOT NULL,
    "Send" boolean DEFAULT false NOT NULL,
    "Receive" boolean DEFAULT false NOT NULL,
    "IMEI" character varying(35) NOT NULL,
    "Client" text NOT NULL,
    "Battery" integer DEFAULT (-1) NOT NULL,
    "Signal" integer DEFAULT (-1) NOT NULL,
    "Sent" integer DEFAULT 0 NOT NULL,
    "Received" integer DEFAULT 0 NOT NULL
);


--
-- TOC entry 187 (class 1259 OID 30602)
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
-- TOC entry 188 (class 1259 OID 30608)
-- Name: scd_accion_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE scd_accion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2309 (class 0 OID 0)
-- Dependencies: 188
-- Name: scd_accion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE scd_accion_id_seq OWNED BY scd_accion.id;


--
-- TOC entry 189 (class 1259 OID 30610)
-- Name: scd_estado; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE scd_estado (
    id bigint NOT NULL,
    nombreestado character varying(75) NOT NULL,
    detalleestado text
);


--
-- TOC entry 190 (class 1259 OID 30616)
-- Name: scd_estado_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE scd_estado_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2310 (class 0 OID 0)
-- Dependencies: 190
-- Name: scd_estado_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE scd_estado_id_seq OWNED BY scd_estado.id;


--
-- TOC entry 191 (class 1259 OID 30618)
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
-- TOC entry 192 (class 1259 OID 30625)
-- Name: scd_historial_operacion_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE scd_historial_operacion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2311 (class 0 OID 0)
-- Dependencies: 192
-- Name: scd_historial_operacion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE scd_historial_operacion_id_seq OWNED BY scd_historial_operacion.id;


--
-- TOC entry 193 (class 1259 OID 30627)
-- Name: scd_historial_permiso; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE scd_historial_permiso (
    id bigint NOT NULL,
    finhisrol timestamp without time zone NOT NULL,
    rol_id bigint NOT NULL,
    usuario_id bigint NOT NULL
);


--
-- TOC entry 194 (class 1259 OID 30630)
-- Name: scd_historial_rol_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE scd_historial_rol_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2312 (class 0 OID 0)
-- Dependencies: 194
-- Name: scd_historial_rol_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE scd_historial_rol_id_seq OWNED BY scd_historial_permiso.id;


--
-- TOC entry 195 (class 1259 OID 30632)
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
-- TOC entry 196 (class 1259 OID 30638)
-- Name: scd_localidad_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE scd_localidad_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2313 (class 0 OID 0)
-- Dependencies: 196
-- Name: scd_localidad_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE scd_localidad_id_seq OWNED BY scd_localidad.id;


--
-- TOC entry 197 (class 1259 OID 30640)
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
-- TOC entry 198 (class 1259 OID 30647)
-- Name: scd_otros_sms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE scd_otros_sms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2314 (class 0 OID 0)
-- Dependencies: 198
-- Name: scd_otros_sms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE scd_otros_sms_id_seq OWNED BY scd_otros_sms.id;


--
-- TOC entry 199 (class 1259 OID 30649)
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
-- TOC entry 200 (class 1259 OID 30652)
-- Name: scd_recibido_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE scd_recibido_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2315 (class 0 OID 0)
-- Dependencies: 200
-- Name: scd_recibido_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE scd_recibido_id_seq OWNED BY scd_recibido.id;


--
-- TOC entry 201 (class 1259 OID 30654)
-- Name: scd_regla_rol; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE scd_regla_rol (
    regla_id bigint NOT NULL,
    rol_id bigint NOT NULL
);


--
-- TOC entry 202 (class 1259 OID 30657)
-- Name: scd_regla_sms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE scd_regla_sms (
    id bigint NOT NULL,
    nombreregla character varying(75) NOT NULL,
    prefijoregla character varying(10) NOT NULL,
    inicioregla timestamp without time zone NOT NULL,
    finregla timestamp without time zone NOT NULL,
    registroregla timestamp without time zone DEFAULT (now())::timestamp(0) without time zone NOT NULL,
    descripcionregla character varying(250)
);


--
-- TOC entry 203 (class 1259 OID 30660)
-- Name: scd_regla_sms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE scd_regla_sms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2316 (class 0 OID 0)
-- Dependencies: 203
-- Name: scd_regla_sms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE scd_regla_sms_id_seq OWNED BY scd_regla_sms.id;


--
-- TOC entry 204 (class 1259 OID 30662)
-- Name: scd_rol; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE scd_rol (
    id integer NOT NULL,
    nombrerol character varying(75) NOT NULL,
    detallerol text
);


--
-- TOC entry 205 (class 1259 OID 30668)
-- Name: scd_rol_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE scd_rol_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2317 (class 0 OID 0)
-- Dependencies: 205
-- Name: scd_rol_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE scd_rol_id_seq OWNED BY scd_rol.id;


--
-- TOC entry 206 (class 1259 OID 30670)
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
-- TOC entry 207 (class 1259 OID 30679)
-- Name: scd_usuario_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE scd_usuario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2318 (class 0 OID 0)
-- Dependencies: 207
-- Name: scd_usuario_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE scd_usuario_id_seq OWNED BY scd_usuario.id;


--
-- TOC entry 208 (class 1259 OID 30681)
-- Name: scd_usuario_rol; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE scd_usuario_rol (
    usuario_id bigint NOT NULL,
    rol_id bigint NOT NULL
);


--
-- TOC entry 186 (class 1259 OID 30556)
-- Name: sentitems; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE sentitems (
    "UpdatedInDB" timestamp(0) without time zone DEFAULT ('now'::text)::timestamp(0) without time zone NOT NULL,
    "InsertIntoDB" timestamp(0) without time zone DEFAULT ('now'::text)::timestamp(0) without time zone NOT NULL,
    "SendingDateTime" timestamp(0) without time zone DEFAULT ('now'::text)::timestamp(0) without time zone NOT NULL,
    "DeliveryDateTime" timestamp(0) without time zone,
    "Text" text NOT NULL,
    "DestinationNumber" character varying(20) DEFAULT ''::character varying NOT NULL,
    "Coding" character varying(255) DEFAULT 'Default_No_Compression'::character varying NOT NULL,
    "UDH" text NOT NULL,
    "SMSCNumber" character varying(20) DEFAULT ''::character varying NOT NULL,
    "Class" integer DEFAULT (-1) NOT NULL,
    "TextDecoded" text DEFAULT ''::text NOT NULL,
    "ID" integer NOT NULL,
    "SenderID" character varying(255) NOT NULL,
    "SequencePosition" integer DEFAULT 1 NOT NULL,
    "Status" character varying(255) DEFAULT 'SendingOK'::character varying NOT NULL,
    "StatusError" integer DEFAULT (-1) NOT NULL,
    "TPMR" integer DEFAULT (-1) NOT NULL,
    "RelativeValidity" integer DEFAULT (-1) NOT NULL,
    "CreatorID" text NOT NULL,
    CONSTRAINT "sentitems_Coding_check" CHECK ((("Coding")::text = ANY ((ARRAY['Default_No_Compression'::character varying, 'Unicode_No_Compression'::character varying, '8bit'::character varying, 'Default_Compression'::character varying, 'Unicode_Compression'::character varying])::text[]))),
    CONSTRAINT "sentitems_Status_check" CHECK ((("Status")::text = ANY ((ARRAY['SendingOK'::character varying, 'SendingOKNoReport'::character varying, 'SendingError'::character varying, 'DeliveryOK'::character varying, 'DeliveryFailed'::character varying, 'DeliveryPending'::character varying, 'DeliveryUnknown'::character varying, 'Error'::character varying])::text[])))
);


--
-- TOC entry 185 (class 1259 OID 30554)
-- Name: sentitems_ID_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE "sentitems_ID_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 2319 (class 0 OID 0)
-- Dependencies: 185
-- Name: sentitems_ID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE "sentitems_ID_seq" OWNED BY sentitems."ID";


--
-- TOC entry 2044 (class 2604 OID 30460)
-- Name: ID; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY inbox ALTER COLUMN "ID" SET DEFAULT nextval('"inbox_ID_seq"'::regclass);


--
-- TOC entry 2056 (class 2604 OID 30483)
-- Name: ID; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY outbox ALTER COLUMN "ID" SET DEFAULT nextval('"outbox_ID_seq"'::regclass);


--
-- TOC entry 2065 (class 2604 OID 30505)
-- Name: ID; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY outbox_multipart ALTER COLUMN "ID" SET DEFAULT nextval('"outbox_multipart_ID_seq"'::regclass);


--
-- TOC entry 2068 (class 2604 OID 30518)
-- Name: ID; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY pbk ALTER COLUMN "ID" SET DEFAULT nextval('"pbk_ID_seq"'::regclass);


--
-- TOC entry 2070 (class 2604 OID 30530)
-- Name: ID; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY pbk_groups ALTER COLUMN "ID" SET DEFAULT nextval('"pbk_groups_ID_seq"'::regclass);


--
-- TOC entry 2096 (class 2604 OID 30684)
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_accion ALTER COLUMN id SET DEFAULT nextval('scd_accion_id_seq'::regclass);


--
-- TOC entry 2097 (class 2604 OID 30685)
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_estado ALTER COLUMN id SET DEFAULT nextval('scd_estado_id_seq'::regclass);


--
-- TOC entry 2099 (class 2604 OID 30686)
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_historial_operacion ALTER COLUMN id SET DEFAULT nextval('scd_historial_operacion_id_seq'::regclass);


--
-- TOC entry 2100 (class 2604 OID 30687)
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_historial_permiso ALTER COLUMN id SET DEFAULT nextval('scd_historial_rol_id_seq'::regclass);


--
-- TOC entry 2101 (class 2604 OID 30688)
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_localidad ALTER COLUMN id SET DEFAULT nextval('scd_localidad_id_seq'::regclass);


--
-- TOC entry 2103 (class 2604 OID 30689)
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_otros_sms ALTER COLUMN id SET DEFAULT nextval('scd_otros_sms_id_seq'::regclass);


--
-- TOC entry 2104 (class 2604 OID 30690)
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_recibido ALTER COLUMN id SET DEFAULT nextval('scd_recibido_id_seq'::regclass);


--
-- TOC entry 2105 (class 2604 OID 30691)
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_regla_sms ALTER COLUMN id SET DEFAULT nextval('scd_regla_sms_id_seq'::regclass);


--
-- TOC entry 2107 (class 2604 OID 30692)
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_rol ALTER COLUMN id SET DEFAULT nextval('scd_rol_id_seq'::regclass);


--
-- TOC entry 2111 (class 2604 OID 30693)
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_usuario ALTER COLUMN id SET DEFAULT nextval('scd_usuario_id_seq'::regclass);


--
-- TOC entry 2090 (class 2604 OID 30567)
-- Name: ID; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY sentitems ALTER COLUMN "ID" SET DEFAULT nextval('"sentitems_ID_seq"'::regclass);


--
-- TOC entry 2113 (class 2606 OID 30467)
-- Name: inbox_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY inbox
    ADD CONSTRAINT inbox_pkey PRIMARY KEY ("ID");


--
-- TOC entry 2119 (class 2606 OID 30512)
-- Name: outbox_multipart_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY outbox_multipart
    ADD CONSTRAINT outbox_multipart_pkey PRIMARY KEY ("ID", "SequencePosition");


--
-- TOC entry 2116 (class 2606 OID 30494)
-- Name: outbox_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY outbox
    ADD CONSTRAINT outbox_pkey PRIMARY KEY ("ID");


--
-- TOC entry 2123 (class 2606 OID 30535)
-- Name: pbk_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pbk_groups
    ADD CONSTRAINT pbk_groups_pkey PRIMARY KEY ("ID");


--
-- TOC entry 2121 (class 2606 OID 30524)
-- Name: pbk_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pbk
    ADD CONSTRAINT pbk_pkey PRIMARY KEY ("ID");


--
-- TOC entry 2125 (class 2606 OID 30552)
-- Name: phones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY phones
    ADD CONSTRAINT phones_pkey PRIMARY KEY ("IMEI");


--
-- TOC entry 2135 (class 2606 OID 30695)
-- Name: pk_estado; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_estado
    ADD CONSTRAINT pk_estado PRIMARY KEY (id);


--
-- TOC entry 2143 (class 2606 OID 30697)
-- Name: pk_localidad; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_localidad
    ADD CONSTRAINT pk_localidad PRIMARY KEY (id);


--
-- TOC entry 2145 (class 2606 OID 30699)
-- Name: pk_otros_sms; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_otros_sms
    ADD CONSTRAINT pk_otros_sms PRIMARY KEY (id);


--
-- TOC entry 2147 (class 2606 OID 30701)
-- Name: pk_recibido; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_recibido
    ADD CONSTRAINT pk_recibido PRIMARY KEY (id);


--
-- TOC entry 2151 (class 2606 OID 30703)
-- Name: pk_regla; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_regla_sms
    ADD CONSTRAINT pk_regla PRIMARY KEY (id);


--
-- TOC entry 2149 (class 2606 OID 30705)
-- Name: pk_regla_rol; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_regla_rol
    ADD CONSTRAINT pk_regla_rol PRIMARY KEY (regla_id, rol_id);


--
-- TOC entry 2157 (class 2606 OID 30707)
-- Name: pk_saf_rol; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_rol
    ADD CONSTRAINT pk_saf_rol PRIMARY KEY (id);


--
-- TOC entry 2133 (class 2606 OID 30709)
-- Name: pk_scd_accion; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_accion
    ADD CONSTRAINT pk_scd_accion PRIMARY KEY (id);


--
-- TOC entry 2139 (class 2606 OID 30711)
-- Name: pk_scd_bitacora; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_historial_operacion
    ADD CONSTRAINT pk_scd_bitacora PRIMARY KEY (id);


--
-- TOC entry 2141 (class 2606 OID 30713)
-- Name: pk_scd_historial_permiso; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_historial_permiso
    ADD CONSTRAINT pk_scd_historial_permiso PRIMARY KEY (id);


--
-- TOC entry 2161 (class 2606 OID 30715)
-- Name: pk_usuario; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_usuario
    ADD CONSTRAINT pk_usuario PRIMARY KEY (id);


--
-- TOC entry 2167 (class 2606 OID 30717)
-- Name: pk_usuario_rol; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_usuario_rol
    ADD CONSTRAINT pk_usuario_rol PRIMARY KEY (usuario_id, rol_id);


--
-- TOC entry 2137 (class 2606 OID 30719)
-- Name: scd_estado_nombreestado_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_estado
    ADD CONSTRAINT scd_estado_nombreestado_key UNIQUE (nombreestado);


--
-- TOC entry 2159 (class 2606 OID 30721)
-- Name: scd_rol_nombrerol_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_rol
    ADD CONSTRAINT scd_rol_nombrerol_key UNIQUE (nombrerol);


--
-- TOC entry 2129 (class 2606 OID 30579)
-- Name: sentitems_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY sentitems
    ADD CONSTRAINT sentitems_pkey PRIMARY KEY ("ID", "SequencePosition");


--
-- TOC entry 2163 (class 2606 OID 30723)
-- Name: unique_correo; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_usuario
    ADD CONSTRAINT unique_correo UNIQUE (correousuario);


--
-- TOC entry 2165 (class 2606 OID 30725)
-- Name: unique_login; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_usuario
    ADD CONSTRAINT unique_login UNIQUE (username);


--
-- TOC entry 2153 (class 2606 OID 30727)
-- Name: unique_nombre_regla; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_regla_sms
    ADD CONSTRAINT unique_nombre_regla UNIQUE (nombreregla);


--
-- TOC entry 2155 (class 2606 OID 30729)
-- Name: unique_patron_regla; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_regla_sms
    ADD CONSTRAINT unique_patron_regla UNIQUE (prefijoregla);


--
-- TOC entry 2114 (class 1259 OID 30495)
-- Name: outbox_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX outbox_date ON outbox USING btree ("SendingDateTime", "SendingTimeOut");


--
-- TOC entry 2117 (class 1259 OID 30496)
-- Name: outbox_sender; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX outbox_sender ON outbox USING btree ("SenderID");


--
-- TOC entry 2126 (class 1259 OID 30580)
-- Name: sentitems_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sentitems_date ON sentitems USING btree ("DeliveryDateTime");


--
-- TOC entry 2127 (class 1259 OID 30582)
-- Name: sentitems_dest; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sentitems_dest ON sentitems USING btree ("DestinationNumber");


--
-- TOC entry 2130 (class 1259 OID 30583)
-- Name: sentitems_sender; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sentitems_sender ON sentitems USING btree ("SenderID");


--
-- TOC entry 2131 (class 1259 OID 30581)
-- Name: sentitems_tpmr; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sentitems_tpmr ON sentitems USING btree ("TPMR");


--
-- TOC entry 2182 (class 2620 OID 30730)
-- Name: filtra_sms_recivido; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER filtra_sms_recivido BEFORE INSERT ON inbox FOR EACH ROW EXECUTE PROCEDURE filtra_sms_recivido();


--
-- TOC entry 2186 (class 2620 OID 30731)
-- Name: guarda_estado; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER guarda_estado BEFORE DELETE OR UPDATE ON scd_estado FOR EACH ROW EXECUTE PROCEDURE guarda_estado();


--
-- TOC entry 2187 (class 2620 OID 30732)
-- Name: nueva_regla; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER nueva_regla BEFORE INSERT ON scd_regla_sms FOR EACH ROW EXECUTE PROCEDURE nueva_regla();

ALTER TABLE scd_regla_sms DISABLE TRIGGER nueva_regla;


--
-- TOC entry 2181 (class 2620 OID 30468)
-- Name: update_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_timestamp BEFORE UPDATE ON inbox FOR EACH ROW EXECUTE PROCEDURE update_timestamp();


--
-- TOC entry 2183 (class 2620 OID 30497)
-- Name: update_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_timestamp BEFORE UPDATE ON outbox FOR EACH ROW EXECUTE PROCEDURE update_timestamp();


--
-- TOC entry 2184 (class 2620 OID 30553)
-- Name: update_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_timestamp BEFORE UPDATE ON phones FOR EACH ROW EXECUTE PROCEDURE update_timestamp();


--
-- TOC entry 2185 (class 2620 OID 30584)
-- Name: update_timestamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_timestamp BEFORE UPDATE ON sentitems FOR EACH ROW EXECUTE PROCEDURE update_timestamp();


--
-- TOC entry 2177 (class 2606 OID 30733)
-- Name: fk_estado_usuario; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_usuario
    ADD CONSTRAINT fk_estado_usuario FOREIGN KEY (estado_id) REFERENCES scd_estado(id) MATCH FULL ON UPDATE CASCADE ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 2172 (class 2606 OID 30738)
-- Name: fk_localidad; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_localidad
    ADD CONSTRAINT fk_localidad FOREIGN KEY (localidad_id) REFERENCES scd_localidad(id) MATCH FULL ON UPDATE CASCADE ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 2178 (class 2606 OID 30743)
-- Name: fk_localidad_usuario; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_usuario
    ADD CONSTRAINT fk_localidad_usuario FOREIGN KEY (localidad_id) REFERENCES scd_localidad(id) MATCH FULL ON UPDATE CASCADE ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 2175 (class 2606 OID 30748)
-- Name: fk_regla; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_regla_rol
    ADD CONSTRAINT fk_regla FOREIGN KEY (regla_id) REFERENCES scd_regla_sms(id) MATCH FULL ON UPDATE CASCADE ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 2174 (class 2606 OID 31329)
-- Name: fk_regla; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_recibido
    ADD CONSTRAINT fk_regla FOREIGN KEY (regla_id) REFERENCES scd_regla_sms(id) MATCH FULL ON UPDATE CASCADE ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 2179 (class 2606 OID 30753)
-- Name: fk_rol; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_usuario_rol
    ADD CONSTRAINT fk_rol FOREIGN KEY (rol_id) REFERENCES scd_rol(id) MATCH FULL ON UPDATE CASCADE ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 2176 (class 2606 OID 30758)
-- Name: fk_rol; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_regla_rol
    ADD CONSTRAINT fk_rol FOREIGN KEY (rol_id) REFERENCES scd_rol(id) MATCH FULL ON UPDATE CASCADE ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 2168 (class 2606 OID 30763)
-- Name: fk_scd_accion; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_accion
    ADD CONSTRAINT fk_scd_accion FOREIGN KEY (rol_id) REFERENCES scd_rol(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2180 (class 2606 OID 30768)
-- Name: fk_usuario; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_usuario_rol
    ADD CONSTRAINT fk_usuario FOREIGN KEY (usuario_id) REFERENCES scd_usuario(id) MATCH FULL ON UPDATE CASCADE ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 2173 (class 2606 OID 30773)
-- Name: fk_usuario; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_recibido
    ADD CONSTRAINT fk_usuario FOREIGN KEY (usuario_id) REFERENCES scd_usuario(id) MATCH FULL ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2170 (class 2606 OID 30778)
-- Name: historial_rol; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_historial_permiso
    ADD CONSTRAINT historial_rol FOREIGN KEY (rol_id) REFERENCES scd_rol(id) MATCH FULL ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2171 (class 2606 OID 30783)
-- Name: historial_usuario; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_historial_permiso
    ADD CONSTRAINT historial_usuario FOREIGN KEY (usuario_id) REFERENCES scd_usuario(id) MATCH FULL ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 2169 (class 2606 OID 30788)
-- Name: usuario; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY scd_historial_operacion
    ADD CONSTRAINT usuario FOREIGN KEY (usuario_id) REFERENCES scd_usuario(id) MATCH FULL ON UPDATE CASCADE ON DELETE RESTRICT;


-- Completed on 2015-11-20 22:49:05 CST

--
-- PostgreSQL database dump complete
--

