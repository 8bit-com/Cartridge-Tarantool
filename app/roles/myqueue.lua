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
                {'data', 'string'},
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
    queue.create_tube('cust_queue', 'fifottl', {
        if_not_exists = true,
        temporary = false,
        format = {
            {'customer_id', 'unsigned'},
            {'name', 'string'},
            {'data', 'string'},
        },
    })
end

local function on_replace_function(customer)
    queue.tube.cust_queue:put(customer, {ttr = 10})

    --local http_client = require('http.client')
    --local json = require('json')
    --local data = 'mail'
    --local body = json.encode(data)
    --local headers = {
    --    ['Content-Type'] = 'application/json',
    --    ['isImportant'] = 'false'
    --}
    --local response = http_client.request('POST', 'http://localhost:8383/camel/mail', body, { headers = headers })
    --log.info(response)
end

-- создаём функцию на получение данных из очереди
local function queue_take()
    local stat = queue.statistics('cust_queue')
    if stat.tasks.ready == 0 then
        return 'Очередь пуста'
    else
        local customer = queue.tube.cust_queue:take(0.01)
        --customer = queue.tube.cust_queue:ack(customer[1])
        return customer
    end
end

-- создаём функцию очистки очереди
local function queue_clean()
    local stat = queue.statistics('cust_queue')
    local count = stat.tasks.ready
    for i = 1, count do
        local customer = queue.tube.cust_queue:take(0.01)
        queue.tube.cust_queue:ack(customer[1])
    end
end

local exported_functions = {
    on_replace_function = on_replace_function,
    queue_take = queue_take,
    queue_clean = queue_clean,
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
    role_name = 'app.roles.myqueue',
    init = init,
    on_replace_function = on_replace_function,
    queue_take = queue_take,
    queue_clean = queue_clean,
}
