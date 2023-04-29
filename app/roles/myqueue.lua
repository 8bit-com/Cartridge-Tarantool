local queue = require('queue')
local log = require('log')

local function init_spaces()
    local customer = box.schema.space.create(
    -- имя спейса для хранения пользователей
        'customer_queue',
    -- дополнительные параметры
        {
            -- формат хранимых кортежей
            format = {
                {'customer_id', 'unsigned'},
                {'name', 'string'},
            },
            -- создадим спейс, только если его не было
            if_not_exists = true,
        }
    )

    -- создадим индекс по id пользователя
    customer:create_index('customer_id', {
        parts = {'customer_id'},
        if_not_exists = true,
    })

    -- Создаем очередь

    queue.create_tube('cust_queue', 'fifo', {
        if_not_exists = true,
        temporary = false,
        max_size = 100,
        format = {
            {'customer_id', 'unsigned'},
            {'name', 'string'},
        },
    })

end

local function on_replace_function(customer)
    queue.tube.cust_queue:put(customer)
end

-- создаём функцию на получение данных из очереди
local function customer_handler()
    if box.space.cust_queue:len() == 0 then
        return 'Очередь пуста'
    else
        local customer = queue.tube.cust_queue:take(0.01)
        queue.tube.cust_queue:ack(customer[1])
        return customer
    end
end

local exported_functions = {
    on_replace_function = on_replace_function,
    customer_handler = customer_handler,
}


local function init(opts)
    if opts.is_master then
        -- вызываем функцию инициализацию спейсов
        init_spaces()

        for name in pairs(exported_functions) do
            box.schema.func.create(name, {if_not_exists = true})
            box.schema.role.grant('public', 'execute', 'function', name, {if_not_exists = true})
        end

    end

    for name, func in pairs(exported_functions) do
        rawset(_G, name, func)
    end

    return true
end

return {
    role_name = 'myqueue',
    init = init,
}
