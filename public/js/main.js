(function ($, undefined) {


    var auth_header = $.cookie("access_token");
    console.log(auth_header,location.pathname);
    if(location.pathname != "/") return;
    $.ajax({
        url: "/api/orgs",
        success: function(data){
            console.log(data);
            var org = null;
            for( var i in data) {
                org = data[i];
                $('body').append("<p>org name="+ org["name"] +"</p>")
            }

        }
    })
})(jQuery);

