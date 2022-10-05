package com.vmware.multisite;

import com.fasterxml.jackson.databind.JsonNode;
import oracle.jdbc.pool.OracleDataSource;
import org.apache.commons.configuration2.Configuration;
import org.apache.commons.configuration2.builder.fluent.Configurations;
import org.apache.commons.configuration2.ex.ConfigurationException;
import org.apache.commons.dbutils.QueryRunner;
import org.apache.commons.lang3.exception.ExceptionUtils;
import org.apache.geode.pdx.PdxInstance;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.sql.DataSource;
import java.io.File;
import java.sql.SQLException;

public class DataSourceUtils {

    private static Logger log = LoggerFactory.getLogger(DataSourceUtils.class);
    private static Configurations configs = new Configurations();
    private static String URL = "url";
    private static String USERNAME = "username";
    private static String PASSWORD = "password";
    private static Configuration PROPERTIES = null;
    private static String INSERTQUERY = "insertquery";
    private static String UPDATEQUERY = "updatequery";
    private static String DELETEQUERY = "deletequery";

    static {
        try {
            PROPERTIES = configs.properties("db.properties");
        } catch (ConfigurationException e) {
            e.printStackTrace();
        }
    }

    static final DataSource buildDataSource(){
        DataSource ds = null;

        try {
            ds = new OracleDataSource();
            ((OracleDataSource)ds).setURL(PROPERTIES.getString(URL));
            ((OracleDataSource)ds).setUser(PROPERTIES.getString(USERNAME));
            ((OracleDataSource)ds).setPassword(PROPERTIES.getString(PASSWORD));

        } catch (Exception e) {
            log.error(ExceptionUtils.getStackTrace(e));
        }

        return ds;
    }

    static final boolean executeInsertQuery(QueryRunner queryRunner, PdxInstance pdxEntry) {
        try {
            String sql = PROPERTIES.getString(INSERTQUERY);
            queryRunner.execute(sql,
                    pdxEntry.getField("id"),
                    pdxEntry.getField("name"),
                    pdxEntry.getField("dob"),
                    pdxEntry.getField("address"),
                    pdxEntry.getField("phone"),
                    pdxEntry.getField("claimdate"),
                    pdxEntry.getField("city"),
                    pdxEntry.getField("amount"));
            return true;
        } catch (Exception e) {
            log.error(ExceptionUtils.getStackTrace(e));
            return false;
        }
    }

    static final boolean executeUpdateQuery(QueryRunner queryRunner, PdxInstance entry) {
        try {
            String sql = PROPERTIES.getString(UPDATEQUERY);
            queryRunner.execute(sql,
                    entry.getField("name"),
                    entry.getField("dob"),
                    entry.getField("address"),
                    entry.getField("phone"),
                    entry.getField("claimdate"),
                    entry.getField("city"),
                    entry.getField("amount"),
                    entry.getField("id"));
            return true;
        } catch (Exception e) {
            log.error(ExceptionUtils.getStackTrace(e));
            return false;
        }
    }

    static final boolean executeDeleteQuery(QueryRunner queryRunner, PdxInstance entry) {
        try {
            String sql = PROPERTIES.getString(DELETEQUERY);
            queryRunner.execute(sql,
                    entry.getField("id"));
            return true;
        } catch (Exception e) {
            log.error(ExceptionUtils.getStackTrace(e));
            return false;
        }
    }

    static final boolean test(QueryRunner queryRunner, JsonNode pdxEntry) {
        try {
            String sql = PROPERTIES.getString(INSERTQUERY);
            queryRunner.execute(sql,
                    pdxEntry.get("id").asInt(),
                    pdxEntry.get("name").asText(),
                    pdxEntry.get("dob").asText(),
                    pdxEntry.get("address").asText(),
                    pdxEntry.get("phone").asText(),
                    pdxEntry.get("claimdate").asText(),
                    pdxEntry.get("city").asText(),
                    pdxEntry.get("amount").asInt());
            return true;
        } catch (SQLException e) {
            e.printStackTrace();
            System.out.println(ExceptionUtils.getStackTrace(e));
            System.out.println(e.getErrorCode());
            System.out.println(e.getSQLState());
            log.info(ExceptionUtils.getStackTrace(e));
            return false;
        }
    }
}
