use ndarray::Array4;
// use ort::execution_providers::CPUExecutionProvider;
// use ort::session::Session;

fn main() {
    //  let session = Session::builder()
    //      .unwrap()
    //      .with_execution_providers([CPUExecutionProvider::default().build()])
    //      .unwrap();

    // Example input: batch of 1 image, 3 channels, 224x224 (e.g. ResNet)
    let input = Array4::<f32>::zeros((1, 3, 224, 224));

    println!("Hello, world!");
}

// use git2::Repository;
//
// fn main() {
//     match Repository::clone("https://github.com/vbrandl/hoc", "test") {
//         Ok(_) => println!("ok"),
//         Err(e) => {
//             println!("Code: {:?}", e.code());
//             println!("Class: {:?}", e.class());
//             println!("Message: {}", e.message());
//         }
//     }
// }
