local cartridge = require('cartridge')
local errors = require('errors')
local crud = require('crud')
local log = require('log')
local os = require('os')
local tnt_kafka = require('kafka')
local json = require('json')

--local cluster_config = cartridge.config_get_deepcopy()
--local hello_section = cluster_config['hello']
--local var = hello_section['name2']
local producer, err = tnt_kafka.Producer.create({ brokers = "localhost:29092" })

local function customer_pop()
    local customer, error = cartridge.rpc_call('app.roles.myqueue', 'queue_take')

    if error then
        return "Internal error"
    end

    if customer == "Очередь пуста" then
        return nil
    else
        return customer[3]
    end
end

local function kafka_producer(customer)
    --local cluster_config = cartridge.config_get_deepcopy()
    --local hello_section = cluster_config['hello']
    --local var = hello_section['name2']
    --local producer, err = tnt_kafka.Producer.create({ brokers = var })
    --if err ~= nil then
    --    log.info(err)
    --    os.exit(1)
    --end
    local err = producer:produce({
        topic = "topic_json2",
        key = "key_json2",
        value = json.encode(customer)
    })
    if err ~= nil then
        log.info(string.format("got error '%s' while sending value '%s'", err, customer))
    else
        log.info(string.format("successfully sent value '%s'", customer))
    end
    --producer:close()
end

local function repo_customer_add(customer)
    local _, err = crud.insert_object('customer', customer)

    if err then
        log.info("ERROR_ADD!!!")
        log.info(err)
    end

    cartridge.rpc_call('app.roles.myqueue', 'on_replace_function', {customer})
    kafka_producer(customer)
end



local exported_functions = {
    customer_pop = customer_pop,
    repo_customer_add = repo_customer_add,
}

local function init(opts)
    if opts.is_master then
        box.schema.user.grant('guest',
            'read,write,execute',
            'universe',
            nil, { if_not_exists = true }
        )
    end

    for name, func in pairs(exported_functions) do
        rawset(_G, name, func)
    end

    return true
end

return {
    role_name = 'app.roles.repo_api',
    init = init,
    dependencies = {'cartridge.roles.crud-router'},
}
