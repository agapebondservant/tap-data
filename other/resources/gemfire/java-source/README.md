To set up:

* Run other/resources/gemfire/java-source/src/main/resources/schema.sql

* Build CacheListener jar for Primary site: 
```
cd other/resources/gemfire/java-source 
.mvnw -s settings.xml clean package -Ddemo.resources.dir=src/main/resources/primary
alter region --name=claims --cache-listener=com.vmware.multisite.SyncOracleCacheListener
cd ../../../..
```

* Build CacheListener jar for Secondary site:
```
cd other/resources/gemfire/java-source 
.mvnw -s settings.xml clean package -Ddemo.resources.dir=src/main/resources/secondary
cd ../../../..
alter region --name=claims --cache-listener=com.vmware.multisite.SyncOracleCacheListener
```