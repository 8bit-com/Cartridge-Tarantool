local cartridge = require('cartridge')
local errors = require('errors')
local crud = require('crud')
local log = require('log')

local err_httpd = errors.new_class("httpd error")

local function customer_pop()
    local customer, error = cartridge.rpc_call('myqueue', 'queue_take')
    log.info(customer[3])

    if error then
        return "Internal error"
    end

    if customer == "Очередь пуста" then
        return "Очередь пуста"
    else
        return customer[3]
    end
end

local exported_functions = {
    customer_pop = customer_pop,
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
    role_name = 'repo_api',
    init = init,
    dependencies = {'cartridge.roles.crud-router'},
}
