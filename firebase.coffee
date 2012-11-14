define 'mobone.firebase', (exports, root) ->
    
    # Helper to get a value from an object via a property or a function.
    getValue = (target, name) ->
        if not target? or not target[name]?
            return
        method = target[name]
        if _.isFunction method then method() else method
    
    
    # Helper to notify after a sync.
    notifyOn: (success, options) =>
        if success and options.success?
            options.success()
        else if not success and options.error?
            options.error()
    
    
    # Sync logic shared between ``FirebaseModel`` and ``Firebone.Collection``.
    firebaseSync: (firebase_cls, method, model, options) ->
        # Default options to an empty dict.
        options = {} if not options?
        # Setup the Firebase reference to the model (note that this uses the
        # collection's url as a base url by default).
        url = getValue model, 'url'
        ref = new firebase_cls url
        # Map CRUD to Firebase actions.
        switch method
            when 'create'
                ref.push model.toJSON(), (success) ->
                    notifyOn success, options
            when 'read'
                ref.once 'value', (snapshot) ->
                    items = _.toArray snapshot.val()
                    if options.success?
                        options.success items, 'success', {}
            when 'update'
                ref.set model.toJSON(), (success) ->
                    notifyOn success, options
            when 'delete'
                ref.remove (success) ->
                    notifyOn success, options
    
    
    # ``FirebaseModel`` is a `Backbone.Model`_ subclass that syncs with
    # a `Firebase reference`_. Use it with the ``FirebaseCollection`` below.
    # 
    # _`Backbone.Model`: http://backbonejs.org/#Model
    # _`Firebase reference`: https://www.firebase.com/docs/creating-references.html
    class FirebaseModel extends Backbone.Model
        idAttribute: '_firebase_name'
        sync: (method, model, options) =>
            # Unpack the firebase class to use.
            c = @collection
            firebase_cls = if c.firebase_cls? then c.firebase_cls else Firebase
            firebaseSync firebase_cls, method, model, options
        
    
    # ``FirebaseCollection`` is a `Backbone.Collection`_ subclass that syncs with
    # a `Firebase reference`_.
    # 
    # When you instantiate, pass in a reference ``url`` to a `Firebase list`_::
    # 
    #     models = null
    #     options = 
    #         url = 'https://YOURAPP.firebaseio.com/some/path'
    #     collection = new FirebaseCollection models, options
    # 
    # Or provide ``collection.url`` or ``collection.url()``, e.g.::
    # 
    #     class MyFBCollection extends FirebaseCollection
    #         url: -> "https://#{appname}.firebaseio.com/#{path}"
    # 
    # Your collection will now stay in sync with your Firebase list, i.e.:
    # 
    # * pushing an item to Firebase will add a model to the collection
    # * removing a model from the Firebase will remove it from the collection
    # 
    # _`Backbone.Collection`: http://backbonejs.org/#Collection
    # _`Firebase reference`: https://www.firebase.com/docs/creating-references.html
    # _`Firebase list`: https://www.firebase.com/docs/managing-lists.html
    class FirebaseCollection extends Backbone.Collection
        model: FirebaseModel
        defaults:
            events: ['child_added', 'child_changed', 'child_removed']
            idAttribute: '_firebase_name'
            url: null
            firebase_cls: null
        
        _add_snapshot: (snapshot) =>
            # Set the model id attribute to be the firebase reference name.
            data = snapshot.val()
            data[@options.idAttribute] = snapshot.name()
            instance = new @model data
            @add instance
            @trigger 'remote_create', instance
            instance
        
        sync: (method, model, options) =>
            firebaseSync @firebase_cls, method, model, options
        
        child_added: (snapshot) =>
            # Add the new child to the collection.
            @_add_snapshot snapshot
        
        child_changed: (snapshot) =>
            # If the child is already in the collection, update it, otherwise
            # add it to the collection.
            instance = @get snapshot.name()
            if instance
                instance.set snapshot.val()
                @trigger 'remote_update', instance
            else 
                @_add_snapshot snapshot
        
        child_removed: (snapshot) =>
            # If the child is in the collection, remove it.
            instance = @get snapshot.name()
            if instance
                @remove instance
                @trigger 'remote_destroy', instance
        
        initialize: (models, options) ->
            # Extend ``@defaults`` with the ``options`` provided.
            @options = _.defaults options, @defaults
            # Unpack the firebase class to use (allows an alternative implementation
            # or mock to be passed in).
            @firebase_cls = @options.firebase_cls or Firebase
            # Get the reference url.
            url = @options.url or getValue this, 'url'
            # Create a firebase reference.
            @firebase = new @firebase_cls url
            # Bind to firebase events.
            for item in @options.events
                @firebase.on item, this[item]
        
    
    exports.FirebaseModel = FirebaseModel
    exports.FirebaseCollection = FirebaseCollection
