package com.vmware.multisite;

import com.mysql.cj.jdbc.MysqlDataSource;
import oracle.jdbc.pool.OracleDataSource;
import org.apache.commons.lang3.exception.ExceptionUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.sql.DataSource;
import java.util.Properties;

public class DataSourceFactory {

    private static Logger LOG = LoggerFactory.getLogger(DataSourceFactory.class);
    private static String URL = "url";
    private static String USERNAME = "username";
    private static String PASSWORD = "password";
    private static Properties ORACLE_PROPERTIES = null;
    private static Properties MYSQL_PROPERTIES = null;

    static {
        try {
            LOG.error("In DataSourceFactory...");
            ORACLE_PROPERTIES = DataSourceUtils.loadProperties("oracle-db.properties");
            MYSQL_PROPERTIES = DataSourceUtils.loadProperties("mysql-db.properties");
        } catch (Exception e) {
            LOG.error(ExceptionUtils.getStackTrace(e));
        }
    }

    static final DataSource buildOracleDataSource(){

        LOG.error("In buildOracleDataSource()...");
        OracleDataSource ds = null;

        try {
            ds = new OracleDataSource();
            ds.setURL(ORACLE_PROPERTIES.getProperty(URL));
            ds.setUser(ORACLE_PROPERTIES.getProperty(USERNAME));
            ds.setPassword(ORACLE_PROPERTIES.getProperty(PASSWORD));

        } catch (Exception e) {
            LOG.error(ExceptionUtils.getStackTrace(e));
        }

        return ds;
    }

    static final DataSource buildMySQLDataSource(){

        LOG.error("In buildMySQLDataSource()...");
        MysqlDataSource ds = new MysqlDataSource();

        try {
            ds.setURL(MYSQL_PROPERTIES.getProperty(URL));
            ds.setUser(MYSQL_PROPERTIES.getProperty(USERNAME));
            ds.setPassword(MYSQL_PROPERTIES.getProperty(PASSWORD));

        } catch (Exception e) {
            LOG.error(ExceptionUtils.getStackTrace(e));
        }

        return ds;
    }
}
