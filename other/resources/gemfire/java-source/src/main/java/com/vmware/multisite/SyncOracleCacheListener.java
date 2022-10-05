package com.vmware.multisite;

import org.apache.commons.dbutils.QueryRunner;
import org.apache.geode.cache.EntryEvent;
import org.apache.geode.cache.util.CacheListenerAdapter;
import org.apache.geode.pdx.PdxInstance;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.sql.DataSource;

@SuppressWarnings("rawtypes")
public class SyncOracleCacheListener extends CacheListenerAdapter {

    private static Logger LOG = LoggerFactory.getLogger(SyncOracleCacheListener.class);
    private DataSource DS = DataSourceUtils.buildDataSource();
    private QueryRunner RUNNER = new QueryRunner(DS);

    @Override
    public void afterCreate(EntryEvent event) {
        LOG.info("In afterCreate...");

        describeEntry(event);

        DataSourceUtils.executeInsertQuery(RUNNER, (PdxInstance)event.getNewValue());

    }

    @Override
    public void afterDestroy(EntryEvent event) {
        LOG.info("In afterDestroy...");

        describeEntry(event);

        DataSourceUtils.executeDeleteQuery(RUNNER, (PdxInstance)event.getNewValue());
    }

    @Override
    public void afterUpdate(EntryEvent event) {
        LOG.info("In afterUpdate...");

        describeEntry(event);

        DataSourceUtils.executeUpdateQuery(RUNNER, (PdxInstance)event.getNewValue());
    }

    private void describeEntry(EntryEvent event) {
        final String regionName = event.getRegion().getName();
        final Object key = event.getKey();
        final Object entryValue = event.getNewValue();
        LOG.info("In region [" + regionName + "] created key [" + key
                + "] value [" + entryValue  + "]");

    }
}