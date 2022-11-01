package com.vmware.multisite;

import org.apache.commons.dbutils.QueryRunner;
import org.apache.geode.cache.Operation;
import org.apache.geode.cache.Region;
import org.apache.geode.cache.asyncqueue.AsyncEvent;
import org.apache.geode.cache.asyncqueue.AsyncEventListener;
import org.apache.geode.pdx.PdxInstance;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.sql.DataSource;
import java.util.Iterator;
import java.util.List;

@SuppressWarnings("rawtypes")
public class SyncOracleCacheAsyncListener implements AsyncEventListener {

    private static Logger LOG = LoggerFactory.getLogger(SyncOracleCacheAsyncListener.class);
    private DataSource DS = DataSourceUtils.buildDataSource();
    private QueryRunner RUNNER = new QueryRunner(DS);


    @Override
    public boolean processEvents(List<AsyncEvent> events) {
        for (Iterator i = events.iterator(); i.hasNext();) {

            AsyncEvent event = (AsyncEvent) i.next();

            final Operation op = event.getOperation();
            Region region = event.getRegion();
            Object value = region.get(event.getKey());

            LOG.error("In processEvents: {} :: {} :: {}", op, region, value);

            if (op.isCreate()) {
                LOG.error("In create...");
                DataSourceUtils.executeInsertQuery(RUNNER, (PdxInstance)value);
            } else if (op.isUpdate()) {
                LOG.error("In update...");
                DataSourceUtils.executeUpdateQuery(RUNNER, (PdxInstance)value);
            } else if (op.isDestroy()) {
                LOG.error("In delete...");
                DataSourceUtils.executeDeleteQuery(RUNNER, (PdxInstance)event.getKey());
            }

        }
        return true;
    }
}