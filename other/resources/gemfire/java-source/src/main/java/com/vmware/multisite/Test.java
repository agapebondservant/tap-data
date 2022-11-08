package com.vmware.multisite;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.commons.dbutils.QueryRunner;

import javax.sql.DataSource;

public class Test {
    public static void main(String[] args) throws JsonProcessingException {
        String json = "{\"id\":19,\"name\":\"Bo\",\"dob\":\"04-19-2022\",\"address\":\"1930 Apple Dr, Wilmington,DE\",\"phone\":\"2029993333\",\"claimdate\":\"09-22-2022\",\"city\":\"Lagos\",\"region\":\"primary\",\"amount\":3000}";
        JsonNode obj = new ObjectMapper().readTree(json);
        //PdxInstance instance = JSONFormatter.fromJSON(json);
        DataSource DS = DataSourceUtils.buildOracleDataSource();
        QueryRunner RUNNER = new QueryRunner(DS);
        DataSourceUtils.test(RUNNER, obj);


    }
}
