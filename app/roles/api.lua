
local cartridge = require('cartridge')
local errors = require('errors')
local crud = require('crud')
local log = require('log')
local os = require('os')
local tnt_kafka = require('kafka')

local err_httpd = errors.new_class("httpd error")

local function http_kafka_producer()
    local producer, err = tnt_kafka.Producer.create({ brokers = "localhost:29092" })
    if err ~= nil then
        log.info(err)
        os.exit(1)
    end

    for i = 1, 10 do
        local message = "test_value " .. tostring(i)
        local err = producer:produce({
            topic = "test_topic",
            key = "test_key",
            value =  message
        })
        if err ~= nil then
            log.info(string.format("got error '%s' while sending value '%s'", err, message))
        else
            log.info(string.format("successfully sent value '%s'", message))
        end
    end

    producer:close()
end

local function http_customer_add(req)
    local customer = req:json()
    local _, err = crud.insert_object('customer', customer)

    if err then
        local resp = req:render({json = {
            info = "Internal error",
            error = err
        }})
        resp.status = 500
        return resp
    end

    cartridge.rpc_call('myqueue', 'on_replace_function', {customer})

    local resp = req:render({json = { info = "Successfully created" }})
    resp.status = 201

    return resp
end

local function http_customer_get(req)
    local customer_id = tonumber(req.tstash.customer_id or 0)
    local customer, err = crud.get('customer', customer_id)
    if err then
        local resp = req:render({json = {
            info = "Internal error",
            error = err
        }})
        resp.status = 500
        return resp
    end

    customer = crud.unflatten_rows(customer.rows, customer.metadata)

    if customer == nil then
        local resp = req:render({json = { info = "Customer not found" }})
        resp.status = 404
        return resp
    end

    local resp = req:render({json = customer})
    resp.status = 200

    return resp
end

local function http_customer_get_all(req)
    local customer, err = crud.select('customer', nil, {fullscan = true})
    if err then
        local resp = req:render({json = {
            info = "Internal error",
            error = err
        }})
        resp.status = 500
        return resp
    end

    customer = crud.unflatten_rows(customer.rows, customer.metadata)

    if customer == nil then
        local resp = req:render({json = { info = "Customer not found" }})
        resp.status = 404
        return resp
    end

    local resp = req:render({json = customer})
    resp.status = 200

    return resp
end

local function http_customer_delete(req)
    local customer_id = tonumber(req.tstash.customer_id or 0)
    local customer, err = crud.delete('customer', customer_id)
    if err then
        local resp = req:render({json = {
            info = "Internal error",
            error = err
        }})
        resp.status = 500
        return resp
    end

    customer = crud.unflatten_rows(customer.rows, customer.metadata)

    if customer == nil then
        local resp = req:render({json = { info = "Customer not found" }})
        resp.status = 404
        return resp
    end

    local resp = req:render({json = customer})
    resp.status = 200

    return resp
end

local function http_customer_delete_all(req)
    local customer, err = crud.select('customer', nil, {fullscan = true})

    if err then
        local resp = req:render({json = {
            info = "Internal error",
            error = err
        }})
        resp.status = 500
        return resp
    end

    customer = crud.unflatten_rows(customer.rows, customer.metadata)

    for i, v in ipairs(customer) do
        crud.delete('customer', v.customer_id)
    end

    if customer == nil then
        local resp = req:render({json = { info = "Customer not found" }})
        resp.status = 404
        return resp
    end

    local resp = req:render({json = customer})
    resp.status = 200

    return resp
end

local function http_customer_update(req)
    local customer = req:json()
    local customer_id = tonumber(customer.customer_id or 0)
    local customer, err = crud.update('customer', customer_id, {{'=', 'name', customer.name}})
    if err then
        local resp = req:render({json = {
            info = "Internal error",
            error = err
        }})
        resp.status = 500
        return resp
    end

    customer = crud.unflatten_rows(customer.rows, customer.metadata)
    if customer == nil then
        local resp = req:render({json = { info = "Customer not found" }})
        resp.status = 404
        return resp
    end

    local resp = req:render({json = customer})
    resp.status = 200

    return resp
end

local function http_customer_pop(req)
    local customer, error = cartridge.rpc_call('myqueue', 'queue_take')

    if error then
        local resp = req:render({json = {
            info = "Internal error",
            error = error
        }})
        resp.status = 500
        return resp
    end

    local headers_true = {
        ['Content-Type'] = 'application/json',
        ['isImportant'] = 'true'
    }
    local headers_false = {
        ['Content-Type'] = 'application/json',
        ['isImportant'] = 'false'
    }

    local resp = req:render({json = customer})
    resp.status = 200

    if customer == "Очередь пуста" then
        resp.headers = headers_false
    else
        resp.headers = headers_true
    end
    return resp
end

local function http_queue_clean(req)
    local _, error = cartridge.rpc_call('myqueue', 'queue_clean')

    if error then
        local resp = req:render({json = {
            info = "Internal error",
            error = error
        }})
        resp.status = 500
        return resp
    end
    local mess = "Очередь пуста"
    local resp = req:render({json = mess})
    resp.status = 200

    return resp
end

local function init(opts)

    if opts.is_master then
        box.schema.user.grant('guest',
            'read,write,execute',
            'universe',
            nil, { if_not_exists = true }
        )
    end

    local httpd = cartridge.service_get('httpd')

    if not httpd then
        return nil, err_httpd:new("not found")
    end

    -- Навешиваем функции-обработчики
    httpd:route(
        { path = '/storage/produce', method = 'GET', public = true },
        http_kafka_producer
    )
    httpd:route(
        { path = '/storage/customers/create', method = 'POST', public = true },
        http_customer_add
    )
    httpd:route(
        { path = '/storage/customers/:customer_id', method = 'GET', public = true },
        http_customer_get
    )
    httpd:route(
        { path = '/storage/customers', method = 'GET', public = true },
        http_customer_get_all
    )
    httpd:route(
        { path = '/storage/customers/delete/:customer_id', method = 'GET', public = true },
        http_customer_delete
    )
    httpd:route(
        { path = '/storage/customers/delete_all', method = 'GET', public = true },
        http_customer_delete_all
    )
    httpd:route(
        { path = '/storage/customers/pop', method = 'GET', public = true },
        http_customer_pop
    )
    httpd:route(
        { path = '/storage/customers/update', method = 'POST', public = true },
        http_customer_update
    )
    httpd:route(
        { path = '/storage/customers/queue_clean', method = 'GET', public = true },
        http_queue_clean
    )
    return true
end

return {
    role_name = 'api',
    init = init,
    dependencies = {'cartridge.roles.crud-router'},
}
