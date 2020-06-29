var publicKey;
function get_epsilon() {
    $.ajax({
        url: "/epsilon",
        dataType: 'json',
        type: 'get',
        success: function(response) {
            $("#epsilon").text(response.epsilon);
        }
    })
}

function get_pubkey() {
    $.ajax({
        url: "/pubkeypem",
        dataType: 'json',
        type: 'get',
        success: function(response) {
            $("#key").text(response);
            publicKey = forge.pki.publicKeyFromPem(response);
        }
    })
}

get_epsilon();
get_pubkey();

function submit_query(query, on_success) {
    var data = {"query":query};
    console.log(typeof(JSON.stringify(data)));
    console.log(JSON.stringify(data));
    $.ajax({
        url: "/query",
        dataType: 'json',
        data: JSON.stringify(query),
        type: 'post',
        success: function(response) {
            on_success(response);
        }
    })
}

//set to run function on button click
$("#submit-query").on("click", function() {
    let inputQuery = $("#query").val();
    submit_query(inputQuery, function(input) {
        console.log(input.result);
        $("#query-output").html(input.result);
        get_epsilon();
    });
});

function submit_insert(insert, on_success) {
    $.ajax({
        url: "/insert",
        data: insert,
        dataType: 'json',
        type: 'POST',
        success: function(response) {
            on_success(response);
        }
    })
}

//set to run function on button click
$("#submit-insert").on("click", function() {
    let inputInsert = String($("#insert").val());
    inputInsert = publicKey.encrypt(inputInsert, 'RSA-OAEP', {md: forge.md.sha1.create()});
    inputInsert = window.btoa(inputInsert);
    json = { value : inputInsert }
    inputInsert = JSON.stringify(json);
    submit_insert(inputInsert, function(input) {
        console.log("successful insert");
    });
});
