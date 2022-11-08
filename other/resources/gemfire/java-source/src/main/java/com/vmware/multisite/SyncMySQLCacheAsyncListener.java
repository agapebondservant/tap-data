package com.vmware.multisite;

import org.apache.commons.dbutils.QueryRunner;
import org.apache.geode.cache.asyncqueue.AsyncEvent;
import org.apache.geode.cache.asyncqueue.AsyncEventListener;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.sql.DataSource;
import java.util.Iterator;
import java.util.List;

@SuppressWarnings("rawtypes")
public class SyncMySQLCacheAsyncListener implements AsyncEventListener {

    private static Logger LOG = LoggerFactory.getLogger(SyncMySQLCacheAsyncListener.class);
    private DataSource DS = DataSourceFactory.buildMySQLDataSource();
    private QueryRunner RUNNER = new QueryRunner(DS);


    @Override
    public boolean processEvents(List<AsyncEvent> events) {
        for (Iterator i = events.iterator(); i.hasNext();) {

            AsyncEvent event = (AsyncEvent) i.next();

            DataSourceUtils.updateDb(event, RUNNER);

        }
        return true;
    }
}