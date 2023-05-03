local cartridge = require('cartridge')
local errors = require('errors')
local crud = require('crud')
local log = require('log')

local function customer_pop()
    local customer, error = cartridge.rpc_call('myqueue', 'queue_take')

    if error then
        return "Internal error"
    end

    if customer == "Очередь пуста" then
        return nil
    else
        return customer[3]
    end
end

local function repo_customer_add(customer)
    local _, err = crud.insert_object('customer', customer)

    if err then
        log.info("ERROR_ADD!!!")
        log.info(err)
    end

    cartridge.rpc_call('myqueue', 'on_replace_function', {customer})

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
    role_name = 'repo_api',
    init = init,
    dependencies = {'cartridge.roles.crud-router'},
}
