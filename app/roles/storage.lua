local function init_spaces()
    local customer = box.schema.space.create(
    -- имя спейса для хранения пользователей
        'customer',
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
        if_not_exists = true,
    })
end

local function init(opts)
    if opts.is_master then
        -- вызываем функцию инициализацию спейсов
        init_spaces()
    end
    return true
end

return {
    role_name = 'storage',
    init = init,
    dependencies = {
        'cartridge.roles.crud-storage',
    },
}
