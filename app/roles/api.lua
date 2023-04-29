local cartridge = require('cartridge')
local errors = require('errors')
local crud = require('crud')
local log = require('log')

local err_httpd = errors.new_class("httpd error")

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
    log.info(customer)

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
    local customer, err = crud.select('customer')
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
        { path = '/storage/customers/pop', method = 'GET', public = true },
        http_customer_pop
    )
    return true
end

return {
    role_name = 'api',
    init = init,
    dependencies = {'cartridge.roles.crud-router'},
}
